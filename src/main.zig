const Proto = enum {
    tcp,
    udp,
};

fn sendToSensor(allocator: Allocator, cfg: SensorCfg, data: *SensorData) !void {
    const message = try std.json.stringifyAlloc(allocator, data, .{ .escape_unicode = false });

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
        try writer.print("{s}\n", .{message});
    }

    if (cfg.verbose) {
        std.log.info("{d}: send_bytes={d}", .{ time.milliTimestamp(), send_bytes });
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(gpa.allocator());
    defer std.process.argsFree(gpa.allocator(), args);

    const input = try flags.parser(args);

    var cfg: SensorCfg = undefined;
    const data = try SensorData.init(allocator);

    data.sensor_data.temp = input.temp * 10;
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

    //try sendToSensor(allocator, cfg, data);
}

const Names = enum {
    temp,
    pwr1,
    pwr2,
};

const SensorData = struct {
    sensor_data: Sensors,

    const Sensors = struct {
        temp: u64 = 350,
        pwr1: u64 = 48,
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

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("set_sensor_lib");
