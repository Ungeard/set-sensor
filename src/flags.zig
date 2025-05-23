pub fn parser(args: [][:0]u8) !Args {
    var diags: flags.Diagnostics = undefined;

    const result = flags.parse(args, "set-sensor", Args, .{
        .diagnostics = &diags,
    }) catch |err| {
        if (err == error.PrintedHelp) {
            std.posix.exit(0);
        }

        std.log.err(
            "\nUnable to parse command '{s}': {s}\n\n",
            .{ diags.command_name, @errorName(err) },
        );

        std.posix.exit(1);
    };

    return result;
}

const Args = struct {
    pub const description =
        \\ set-sensor is a small tool that provides a way to send a pre-defined
        \\ JSON data-set to a virtual WeOS device.
    ;

    pub const descriptions = .{
        .udp = "Select to use udp as the sending protocol.",
        .temp = "Select temperature value.",
        .pwr1 = "Select power input value for input1.",
        .pwr2 = "Select power input value for input2.",
        .verbose = "Verbose output.",
    };

    udp: bool = false,
    temp: u64 = 35,
    pwr1: u64 = 48,
    pwr2: u64 = 0,
    verbose: bool,

    positional: struct {
        addr: []const u8 = "127.0.0.1",
        port: u16 = 7200,

        pub const descriptions = .{
            .addr = "Address where the sensor can be reached.",
            .port = "Port that is used to communicate with sensor.",
        };
    },

    command: union(enum) {},
    pub const switches = .{
        .verbose = 'V',
        .udp = 'u',
    };
};

const ArgIter = std.process.ArgIterator;

const std = @import("std");
const flags = @import("flags");
