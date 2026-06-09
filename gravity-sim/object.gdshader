shader_type canvas_item;

varying vec4 custom_data;

void vertex() {
	// Bridge custom instance data down to the fragment processor
	custom_data = INSTANCE_CUSTOM;
}

void fragment() {
	float speed = custom_data.b;
    
	// Blue for slower objects, turning red as velocities spike
	vec3 slow = vec3(0.2, 0.4, 1.0);
	vec3 fast = vec3(1.0, 0.2, 0.2);
    
	// Scaling denominator adjustment matches heat visibility threshold
	float factor = clamp(speed / 400.0, 0.0, 1.0);
	vec3 final_color = mix(slow, fast, factor);
	
	// Fast circle coordinate masking filter
	if(distance(UV, vec2(0.5)) > 0.5){
		discard;
	}
	
	COLOR = vec4(final_color, 1.0);
}