uniform mat4 projectionMatrix;
uniform mat4 modelMatrix;
uniform mat4 viewMatrix;

varying vec4 vertexColor;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    vertexColor = VertexColor;
    return projectionMatrix * viewMatrix * modelMatrix * vertex_position;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 pixcoord)
{
    // get color from the texture
    vec4 texcolor = Texel(tex, texcoord);

    // if this pixel is invisible, get rid of it
    if (texcolor.a == 0.0) { discard; }

    vec3 result = (1.0) * (texcolor * color).rgb;

    // draw the color from the texture multiplied by the light amount
    //float lightness = (diffuse + ambient + specular);
    return vec4(result, 1.0);
}
#endif