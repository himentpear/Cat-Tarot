shader_type spatial;
uniform vec4 tint : source_color = vec4(0.26,0.12,0.062,1.0);
uniform bool fabric = false;
varying vec3 point;
float hash(vec2 p){return fract(sin(dot(p,vec2(112.27,37.13)))*43758.5453);}
float noise2(vec2 p){
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){point=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
	if(fabric){
		float folds=sin(point.x*7.2+point.z*1.1+1.6*sin(point.z*1.8+point.x*.8));
		float pile=noise2(point.xz*vec2(11.,17.));
		float nap=noise2(point.xz*vec2(170.,140.));
		ALBEDO=tint.rgb*(.45+.47*pile+.13*folds+.10*nap);
		ROUGHNESS=.88;
		SPECULAR=.15;
	}else{
		vec2 p=vec2(point.x+point.z,point.y+point.z*.19);
		float grain=noise2(p*vec2(1.2,56.)+3.*noise2(p*2.));
		float ring=sin(39.*p.y+6.*noise2(p*vec2(3.,7.)));
		ALBEDO=tint.rgb*(.50+.49*grain+.14*ring);
		ROUGHNESS=.51+.16*grain;
		SPECULAR=.34;
	}
}
