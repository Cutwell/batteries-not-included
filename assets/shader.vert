uniform mat4 projectionMatrix;
uniform mat4 modelMatrix;
uniform mat4 viewMatrix;

varying vec4 vertexColor;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    vertexColor = VertexColor;
    return projectionMatrix * viewMatrix * modelMatrix * vertex_position;
}
