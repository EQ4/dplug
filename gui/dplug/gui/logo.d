/**
* Copyright: Copyright Auburn Sounds 2015 and later.
* License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
* Authors:   Guillaume Piolat
*/
module dplug.gui.logo;

import std.math;
import gfm.image;
import dplug.gui;

class UILogo : UIElement
{
public:

    /// Change this to point to your website
    string targetURL = "http://example.com";
    float animationTimeConstant = 30.0f;

    this(UIContext context, Image!RGBA diffuseImage)
    {
        super(context);
        _diffuseImage = diffuseImage;
        _animation = 0;
    }

    override void onAnimate(double dt, double time)
    {
        float target = ( isDragged() || isMouseOver() ) ? 1 : 0;

        float newAnimation = lerp(_animation, target, 1.0 - exp(-dt * animationTimeConstant));

        if (abs(newAnimation - _animation) > 0.001f)
        {
            _animation = newAnimation;
            setDirty();
        }
    }

    override void onDraw(ImageRef!RGBA diffuseMap, ImageRef!L16 depthMap, ImageRef!RGBA materialMap, box2i[] dirtyRects)
    {
        foreach(dirtyRect; dirtyRects)
        {
            auto croppedDiffuseIn = _diffuseImage.crop(dirtyRect);
            auto croppedDiffuseOut = diffuseMap.crop(dirtyRect);

            int w = dirtyRect.width;
            int h = dirtyRect.height;

            ubyte emissive = cast(ubyte)(0.5f + lerp(0.0f, 40.0f, _animation));

            for(int j = 0; j < h; ++j)
            {
                RGBA[] input = croppedDiffuseIn.scanline(j);
                RGBA[] output = croppedDiffuseOut.scanline(j);

                for(int i = 0; i < w; ++i)
                {
                    ubyte alpha = input[i].a;
                    RGBA color = RGBA.op!q{.blend(a, b, c)}(input[i], output[i], alpha);
                    // 13 is the default emissive
                    color.a = cast(ubyte)( (128 + 13 * 256 + (emissive * color.a) ) >> 8);
                    output[i] = color;
                }
            }
        }
    }

    override bool onMouseClick(int x, int y, int button, bool isDoubleClick, MouseState mstate)
    {
        import std.process;
        browse(targetURL);
        return true;
    }

private:
    float _animation;
    Image!RGBA _diffuseImage;
}
