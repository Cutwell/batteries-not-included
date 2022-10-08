// variables provided by g3d's vertex shader
varying vec4 vpos;
varying vec3 vertexNormal;
varying vec3 fragpos;

// the model matrix comes from the camera automatically
uniform vec3 lightPosition = vec3(100,1,20);
//uniform vec3 lightPosition;
uniform float ambientStrength = 0.1;
uniform float specularStrength = 0.5;

uniform mat4 projectionMatrix;
uniform mat4 modelMatrix;
uniform mat4 viewMatrix;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    // vec3(view * model * vec4(aPos, 1.0));
    fragpos = (viewMatrix * modelMatrix * vertex_position).xyz;
    vpos = vertex_position;
    vertexNormal = (transform_projection * vec4(normalize(lightPosition), 1.0)).xyz;
    return projectionMatrix * viewMatrix * modelMatrix * vertex_position;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 pixcoord) {
    // ambient light
    vec3 ambient = ambientStrength * vec3(1.0, 1.0, 1.0);

    // diffuse light
    // computed by the dot product of the normal vector and the direction to the light source
    vec3 lightDirection = normalize(lightPosition.xyz - vpos.xyz);
    vec3 normal = normalize(mat3(modelMatrix) * vertexNormal);
    float diff = max(dot(lightDirection, normal), 0);
    vec3 diffuse = diff * vec3(1.0, 1.0, 1.0);

    vec3 viewDir = normalize(vpos - fragpos);
    vec3 reflectDir = reflect(-lightDirection, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
    vec3 specular = specularStrength * spec * vec3(1.0, 1.0, 1.0); 

    // get color from the texture
    vec4 texcolor = Texel(tex, texcoord);
    // if this pixel is invisible, get rid of it
    if (texcolor.a == 0.0) { discard; }

    vec3 result = (ambient + diffuse - 0.2) * (texcolor * color).rgb;

    // draw the color from the texture multiplied by the light amount
    //float lightness = (diffuse + ambient + specular);
    return vec4(result, 1.0);
}
#endif