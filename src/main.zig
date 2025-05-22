fn sendToSensor(allocator: Allocator, cfg: SensorCfg, data: *SensorData) !void {
    const sockfd = try posix.socket(posix.AF.INET, posix.SOCK.DGRAM | posix.SOCK.CLOEXEC, 0);
    defer posix.close(sockfd);

    try posix.connect(sockfd, &cfg.addr.any, cfg.addr.getOsSockLen());

    const message = try std.json.stringifyAlloc(allocator, data, .{});

    const send_bytes = try posix.send(sockfd, message, 0);
    if (cfg.verbose) {
        std.log.info("{d}: send_bytes={d}", .{time.milliTimestamp(), send_bytes});
    }

}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var cfg: SensorCfg = undefined;
    const data = try SensorData.init(allocator);

    cfg.addr = try std.net.Address.resolveIp("127.0.0.1", 7200);
    cfg.verbose = true;

    try sendToSensor(allocator, cfg, data);

}

const SensorData = struct {
    sensor_data: Sensors,

    const Sensors = struct {
        temp: u16 = 25,
        pwr1: u16 = 30,
        pwr2: u16 = 0,
    };

    fn init(allocator: Allocator) !*SensorData {
        const data = try allocator.create(SensorData);
        data.sensor_data = Sensors{};

        return data;
    }
};

const SensorCfg = struct {
    addr: std.net.Address,
    verbose: bool,
};


const std = @import("std");
const posix = std.posix;
const net = std.net;
const time = std.time;
const Allocator = std.mem.Allocator;

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("set_sensor_lib");
