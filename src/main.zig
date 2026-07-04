const std = @import("std");
const raylib = @import("raylib");

const player_size = 10;
const bullet_size = 10;
const mushroom_size = 10;

const tiles_width = 30;
const tiles_height = 30;
const tile_size = 10;

const game_width = (tiles_width * tile_size);
const screen_width = game_width + 150;
const screen_height = tiles_height * tile_size;

const Mushrooms = [200]Mushroom;
const Bugs = [200]Bug;

pub fn main(init: std.process.Init) void {
    var io_rand: std.Random.IoSource = .{ .io = init.io };
    var rand = io_rand.interface();

    raylib.initWindow(screen_width, screen_height, "Centipeid");
    defer raylib.closeWindow();

    var player: Player = std.mem.zeroes(Player);
    var bullet: Bullet = std.mem.zeroes(Bullet);

    var mushrooms_size: usize = std.mem.zeroes(usize);
    var mushrooms: Mushrooms = std.mem.zeroes(Mushrooms);

    var bugs_size: usize = std.mem.zeroes(usize);
    var bugs: Bugs = std.mem.zeroes(Bugs);

    spawn_mushrooms(&mushrooms, &mushrooms_size, 60, &rand);
    spawn_bugs(&bugs, &bugs_size, 8);

    while (raylib.windowShouldClose() == false) {
        const delta = raylib.getFrameTime();

        player.control_movement(delta);
        player.control_shooting(&bullet);
        bullet.update(delta);

        for (0..bugs_size) |bug_index| {
            bugs[bug_index].update(&mushrooms, delta);
        }

        handle_collision(&mushrooms, &mushrooms_size, &bullet, &rand);
        handle_bug_collision(&bugs, &bugs_size, &bullet);

        raylib.beginDrawing();
        raylib.clearBackground(.black);

        player.draw();
        bullet.draw();

        for (0..mushrooms_size) |mushroom_index| {
            mushrooms[mushroom_index].draw();
        }

        for (0..bugs_size) |bug_index| {
            bugs[bug_index].draw();
        }

        raylib.drawRectangle(game_width, 0, 2, screen_height, .white);

        raylib.endDrawing();
    }
}

fn spawn_mushroom(mushrooms: *Mushrooms, mushrooms_size: *usize, random: *std.Random) void {
    var retry_count: i32 = 0;
    var retry: bool = true;
    while (retry) {
        retry = false;
        const random_x = random.intRangeAtMost(i32, 0, tiles_width);
        const random_y = random.intRangeAtMost(i32, 0, tiles_height);

        const a = has_mushroom(mushrooms, random_x, random_y + 2);
        const b = has_mushroom(mushrooms, random_x, random_y - 2);
        if (a == true or b == true) {
            retry_count = retry_count + 1;
            retry = retry_count < 3;
        }

        mushrooms[mushrooms_size.*] = .{
            .x = random_x,
            .y = random_y,
            .health = 3,
        };
        mushrooms_size.* = mushrooms_size.* + 1;
    }
}

fn spawn_mushrooms(mushrooms: *Mushrooms, mushrooms_size: *usize, count: usize, random: *std.Random) void {
    for (0..count) |_| {
        spawn_mushroom(mushrooms, mushrooms_size, random);
    }
}

fn remove_mushroom(mushrooms: *Mushrooms, index: usize, mushrooms_size: *usize) void {
    if (index >= mushrooms_size.*) {
        return;
    }

    for (index..mushrooms_size.* - 1) |mi| {
        mushrooms[mi] = mushrooms[mi + 1];
    }

    mushrooms[mushrooms_size.*] = std.mem.zeroes(Mushroom);

    mushrooms_size.* = mushrooms_size.* - 1;
}

fn remove_bug(bugs: *Bugs, index: usize, bugs_size: *usize) void {
    if (index >= bugs_size.*) {
        return;
    }
    for (index..bugs_size.* - 1) |bi| {
        bugs[bi] = bugs[bi + 1];
    }
    bugs[bugs_size.*] = std.mem.zeroes(Bug);
    bugs_size.* = bugs_size.* - 1;
}

fn spawn_bugs(bugs: *Bugs, bugs_size: *usize, count: usize) void {
    for (bugs_size.*..bugs_size.* + count, 0..) |index, c| {
        bugs[index] = std.mem.zeroes(Bug);
        bugs[index].from_x = 8;
        bugs[index].to_x = 8;
        bugs[index].from_y = @as(i32, @intCast(c)) * -1 - 1;
        bugs[index].to_y = (@as(i32, @intCast(c)) * -1);
        bugs[index].move_direction = .RIGHT;
    }
    bugs_size.* = bugs_size.* + count;
}

fn handle_collision(mushrooms: *Mushrooms, mushrooms_size: *usize, bullet: *Bullet, random: *std.Random) void {
    for (0..mushrooms_size.*) |mushroom_index| {
        var mushroom = &mushrooms[mushroom_index];

        if (collides(mushroom.get_pixel_x(), mushroom.get_pixel_y(), 10, @intFromFloat(bullet.position.x), @intFromFloat(bullet.position.y), 10)) {
            mushroom.health = mushroom.health - 1;
            bullet.position.x = -20;

            if (mushroom.health <= 0) {
                remove_mushroom(mushrooms, mushroom_index, mushrooms_size);
                spawn_mushroom(mushrooms, mushrooms_size, random);
            }
            return;
        }
    }
}

fn handle_bug_collision(bugs: *Bugs, bugs_size: *usize, bullet: *Bullet) void {
    for (0..bugs_size.*) |bug_index| {
        const bug = &bugs[bug_index];

        if (collides(@intFromFloat(bug.get_pixel_x()), @intFromFloat(bug.get_pixel_y()), 10, @intFromFloat(bullet.position.x), @intFromFloat(bullet.position.y), 10)) {
            bullet.position.x = -20;
            remove_bug(bugs, bug_index, bugs_size);
        }
    }
}

fn collides(x1: i32, y1: i32, size1: i32, x2: i32, y2: i32, size2: i32) bool {
    const collides_x = x2 >= x1 and x2 <= x1 + size1 or
        x2 + size2 >= x1 and x2 + size2 <= x1 + size1;

    const collides_y = y2 >= y1 and y2 <= y1 + size1 or
        y2 + size2 >= y1 and y2 + size2 <= y1 + size1;

    return collides_x and collides_y;
}

const Direction = enum {
    LEFT,
    RIGHT,
};

const VerticalDirection = enum {
    Up,
    Down,
};

const Mushroom = struct {
    x: i32,
    y: i32,
    health: i32,

    pub fn draw(self: Mushroom) void {
        raylib.drawRectangle(
            self.get_pixel_x(),
            self.get_pixel_y(),
            tile_size,
            @intFromFloat(tile_size * (@as(f32, @floatFromInt(self.health)) / 3.0)),
            .green,
        );
    }

    pub fn get_pixel_x(self: Mushroom) i32 {
        return self.x * tile_size;
    }

    pub fn get_pixel_y(self: Mushroom) i32 {
        return self.y * tile_size;
    }
};

const Bug = struct {
    from_x: i32,
    from_y: i32,
    to_x: i32,
    to_y: i32,
    tween: f32,
    turned: bool,
    move_direction: Direction,
    vertical_direction: VerticalDirection,

    pub fn draw(self: Bug) void {
        const x: i32 = @intFromFloat(self.get_pixel_x());
        const y: i32 = @intFromFloat(self.get_pixel_y());
        raylib.drawRectangle(x, y, tile_size, tile_size, .red);
    }

    pub fn update(self: *Bug, mushrooms: *Mushrooms, delta: f32) void {
        if (self.tween >= 1.0) {
            self.from_x = self.to_x;
            self.from_y = self.to_y;

            if (self.turned == true and self.move_direction == .LEFT) {
                if (has_mushroom(mushrooms, self.to_x + 1, self.to_y)) {
                    self.to_x = self.to_x - 1;
                    self.move_direction = .LEFT;
                } else {
                    self.to_x = self.to_x + 1;
                    self.move_direction = .RIGHT;
                }
                self.turned = false;
                self.move_direction = .RIGHT;
            } else if (self.turned == true and self.move_direction == .RIGHT) {
                if (has_mushroom(mushrooms, self.to_x - 1, self.to_y)) {
                    self.to_x = self.to_x + 1;
                    self.move_direction = .RIGHT;
                } else {
                    self.to_x = self.to_x - 1;
                    self.move_direction = .LEFT;
                }
                self.turned = false;
            } else if (self.move_direction == .RIGHT and has_mushroom(mushrooms, self.to_x + 1, self.to_y) or
                self.move_direction == .LEFT and has_mushroom(mushrooms, self.to_x - 1, self.to_y) or
                self.to_x - 1 < 0 or
                self.to_x + 1 >= tiles_width)
            {
                if (has_mushroom(mushrooms, self.to_x, self.to_y + 1)) {
                    self.to_y = self.to_y - 1;
                } else {
                    self.to_y = self.to_y + 1;
                }
                self.turned = true;
            } else if (self.from_y < 0) { // Above screen
                self.to_x = self.to_x + 0;
                self.to_y = self.to_y + 1;
            } else if (self.move_direction == .RIGHT) {
                self.to_x = self.to_x + 1;
                self.to_y = self.to_y + 0;
            } else if (self.move_direction == .LEFT) {
                self.to_x = self.to_x - 1;
                self.to_y = self.to_y + 0;
            }
            self.tween = 0.0;
        }
        self.tween = self.tween + (delta * 8.0);
    }

    fn get_pixel_x(self: Bug) f32 {
        const from: f32 = @floatFromInt(self.from_x * tile_size);
        const to: f32 = @floatFromInt(self.to_x * tile_size);
        return tween(from, to, self.tween);
    }

    fn get_pixel_y(self: Bug) f32 {
        const from: f32 = @floatFromInt(self.from_y * tile_size);
        const to: f32 = @floatFromInt(self.to_y * tile_size);
        return tween(from, to, self.tween);
    }
};

fn tween(from: f32, to: f32, t: f32) f32 {
    const d = 1.0 - std.math.cos((t * std.math.pi) / 2.0);
    return from + (to - from) * d;
}

fn has_mushroom(mushrooms: *Mushrooms, x: i32, y: i32) bool {
    for (mushrooms) |mushroom| {
        if (mushroom.x == x and mushroom.y == y) {
            return true;
        }
    }

    return false;
}

const Player = struct {
    position: raylib.Vector2,

    pub fn draw(self: Player) void {
        raylib.drawRectangle(@intFromFloat(self.position.x), @intFromFloat(self.position.y), 10, 10, .blue);
    }

    pub fn control_movement(self: *Player, delta: f32) void {
        var direction = std.mem.zeroes(raylib.Vector2);

        if (raylib.isKeyDown(.right)) {
            direction.x = direction.x + 1;
        }

        if (raylib.isKeyDown(.left)) {
            direction.x = direction.x - 1;
        }

        if (raylib.isKeyDown(.up)) {
            direction.y = direction.y - 1;
        }

        if (raylib.isKeyDown(.down)) {
            direction.y = direction.y + 1;
        }

        const normalize_direction = raylib.math.vector2Normalize(direction);

        self.position = self.position.add(normalize_direction.scale(180 * delta));
    }

    pub fn control_shooting(self: Player, bullet: *Bullet) void {
        if (raylib.isKeyPressed(.space)) {
            bullet.position = self.position;
        }
    }
};

const Bullet = struct {
    position: raylib.Vector2,

    pub fn draw(self: Bullet) void {
        raylib.drawRectangle(@intFromFloat(self.position.x), @intFromFloat(self.position.y), 8, 8, .white);
    }

    pub fn update(self: *Bullet, delta: f32) void {
        self.position.y -= 480 * delta;
    }
};
