shader_type canvas_item;
// Moving glints on the town's water (stream, puddles). Only bluish pixels shimmer, so the muddy
// banks of the LPC water tiles stay still. Works on the whole TileMapLayer, without UV tricks.

uniform float speed = 1.6;
uniform float strength = 0.22;
uniform float scale = 0.11;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float water = smoothstep(0.05, 0.2, color.b - color.r);
	float wave = sin(world_position.x * scale + TIME * speed) * sin(world_position.y * scale * 1.7 - TIME * speed * 0.8);
	float glint = smoothstep(0.75, 1.0, wave);
	float drift = 0.5 + 0.5 * sin(world_position.y * scale * 0.6 - TIME * speed * 1.3);
	color.rgb += water * (glint * strength + drift * 0.04);
	COLOR = color * COLOR;
}
