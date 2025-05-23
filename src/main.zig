/// Appends a new line ('\n') to the String (str) and returns a new string
/// allocation.
fn appendNewLine(allocator: Allocator, str: []u8) ![]u8 {
    var buf: [100]u8 = undefined;
    const fmt = try std.fmt.bufPrint(buf[0..], "{s}\n", .{str});
    return allocator.dupe(u8, fmt);
}

/// Sends SensorData (data) with either TCP or UDP dependent on SensorCfg (cfg).
///
/// The information is sent as a json-string that is terminated by
/// a new line ('\n') character.
fn sendToSensor(allocator: Allocator, cfg: SensorCfg, data: *SensorData) !void {
    const json_data = try std.json.stringifyAlloc(allocator, data, .{ .escape_unicode = false });
    const message = try appendNewLine(allocator, json_data);
    allocator.free(json_data);

    var send_bytes: usize = undefined;

    if (cfg.proto == Proto.udp) {
        const sockfd = try posix.socket(posix.AF.INET, posix.SOCK.DGRAM | posix.SOCK.CLOEXEC, 0);
        defer posix.close(sockfd);

        try posix.connect(sockfd, &cfg.addr.any, cfg.addr.getOsSockLen());
        send_bytes = try posix.send(sockfd, message, 0);
    } else {
        const sockfd = try posix.socket(posix.AF.INET, posix.SOCK.STREAM, posix.IPPROTO.TCP);
        defer posix.close(sockfd);

        try posix.connect(sockfd, &cfg.addr.any, cfg.addr.getOsSockLen());

        send_bytes = try posix.write(sockfd, message);

        var buf: [1024]u8 = undefined;
        const rcv_bytes = try posix.read(sockfd, &buf);
        if (cfg.verbose) {
            std.log.info("{d}: rcv_bytes={d}", .{ time.milliTimestamp(), rcv_bytes });
            std.log.debug("rcv: {s}", .{buf});
        }
    }

    if (cfg.verbose) {
        std.log.info("{d}: send_bytes={d}", .{ time.milliTimestamp(), send_bytes });
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const input = try flags.parser(args);

    var cfg: SensorCfg = undefined;
    const data = try SensorData.init(allocator);

    // -nographic --machine pc-i440fx-4.2 -fw_cfg name=opt/id,string=6103E -chardev socket,id=weosctl,host=localhost,port=4444,server=on,wait=off -device pci-serial,chardev=weosctl

    data.sensor_data.temp = input.temp;
    if (input.verbose) std.log.debug("input.temp: {d}", .{input.temp});
    data.sensor_data.pwr1 = input.pwr1;
    if (input.verbose) std.log.debug("input.pwr1: {d}", .{input.pwr1});
    data.sensor_data.pwr2 = input.pwr2;
    if (input.verbose) std.log.debug("input.pwr2: {d}", .{input.pwr2});

    cfg.addr = try std.net.Address.resolveIp(input.positional.addr, input.positional.port);
    if (input.udp) {
        cfg.proto = .udp;
    }
    if (input.verbose) {
        cfg.verbose = true;
    }

    try sendToSensor(allocator, cfg, data);
}

const Proto = enum {
    tcp,
    udp,
};

const SensorData = struct {
    sensor_data: Sensors,

    const Sensors = struct {
        temp: u64 = undefined,
        pwr1: u64 = undefined,
        pwr2: u64 = undefined,
    };

    fn init(allocator: Allocator) !*SensorData {
        const data = try allocator.create(SensorData);
        data.sensor_data = Sensors{};

        return data;
    }
};

const SensorCfg = struct {
    addr: std.net.Address,
    proto: Proto = .tcp,
    verbose: bool,
};

const std = @import("std");
const flags = @import("flags.zig");
const posix = std.posix;
const net = std.net;
const time = std.time;
const Allocator = std.mem.Allocator;
