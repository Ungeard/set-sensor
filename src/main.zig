fn appendNewLine(allocator: Allocator, str: []u8) ![]u8 {
    var buf: [100]u8 = undefined;
    const fmt = try std.fmt.bufPrint(buf[0..], "{s}\n", .{str});
    return allocator.dupe(u8, fmt);
}

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
        const stream = try net.tcpConnectToAddress(cfg.addr);
        defer stream.close();

        var writer = stream.writer();
        send_bytes = try writer.write(message);
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

    data.sensor_data.temp = input.temp * 0;
    data.sensor_data.pwr1 = input.pwr1;
    data.sensor_data.pwr2 = input.pwr2;

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
        temp: u64 = 0,
        pwr1: u64 = 0,
        pwr2: u64 = 0,
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
