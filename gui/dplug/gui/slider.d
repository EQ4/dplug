/**
* Copyright: Copyright Auburn Sounds 2015 and later.
* License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
* Authors:   Guillaume Piolat
*/
module dplug.gui.slider;

import std.math;
import dplug.gui.element;
import dplug.gui.drawex;
import dplug.client.params;

class UISlider : UIElement, IParameterListener
{
public:

    this(UIContext context, FloatParameter param)
    {
        super(context);
        _param = param;
        _param.addListener(this);
        _sensivity = 1.0f;
        _initialized = true;
        clearCrosspoints();
    }

    ~this()
    {
        if (_initialized)
        {
            debug ensureNotInGC("UISlider");
            _param.removeListener(this);
            _initialized = false;
        }
    }

    /// Returns: sensivity.
    float sensivity()
    {
        return _sensivity;
    }

    /// Sets sensivity.
    float sensivity(float sensivity)
    {
        return _sensivity = sensivity;
    }

    override void onDraw(ImageRef!RGBA diffuseMap, ImageRef!L16 depthMap, ImageRef!RGBA materialMap, box2i[] dirtyRects)
    {
        int width = _position.width;
        int height = _position.height;

        // The switch is in a subrect

        box2i holeRect =  box2i ( cast(int)(0.5f + width * 0.4f), 2, cast(int)(0.5f + width * (1-0.4f)), height - 2 );

        float value = _param.getNormalized();

        int handleHeight = (height + 2) / 4;
        int handleWidth = cast(int)(0.5f + width * 0.7f);

        int posX = cast(int)(0.5f + (width - handleWidth) / 2);
        int posY = cast(int)(0.5f + (1 - value) * (height - handleHeight));
        assert(posX >= 0);
        assert(posY >= 0);

        box2i handleRect = box2i(posX, posY, posX + handleWidth, posY + handleHeight);


        // Paint deeper hole
        {
            box2i holeBlack = box2i(holeRect.min.x, holeRect.min.y, holeRect.max.x, std.algorithm.max(holeRect.min.y, posY - 1));
            box2i holeLit = box2i(holeRect.min.x, std.algorithm.min(holeRect.max.y, posY + handleHeight), holeRect.max.x, holeRect.max.y);

            diffuseMap.crop(holeBlack).fill(RGBA(150, 40, 20, 8));
            diffuseMap.crop(holeLit).fill(RGBA(230, 80, 43, 192));
            depthMap.crop(holeRect).fill(L16(30000));
        }

        // Paint handle of slider
        {
            ubyte emissive = 16;
            if (isDragged || isMouseOver)
                emissive = 64;

            Material handleMat = Material.silver;

            diffuseMap.crop(handleRect).fill(handleMat.diffuse(emissive));

            auto c0 = L16(15000);
            auto c1 = L16(65535);
            auto c2 = L16(51400);

            int h0 = handleRect.min.y;
            int h1 = (handleRect.min.y * 3 + handleRect.max.y + 2) / 4;
            int h2 = handleRect.center.y;
            int h3 = (handleRect.min.y + handleRect.max.y * 3 + 2) / 4;
            int h4 = handleRect.max.y;

            verticalSlope(depthMap, box2i(handleRect.min.x, h0, handleRect.max.x, h1), c0, c1);
            verticalSlope(depthMap, box2i(handleRect.min.x, h1, handleRect.max.x, h2), c1, c2);
            verticalSlope(depthMap, box2i(handleRect.min.x, h2, handleRect.max.x, h3), c2, c1);
            verticalSlope(depthMap, box2i(handleRect.min.x, h3, handleRect.max.x, h4), c1, c0);

            materialMap.crop(handleRect).fill(handleMat.material(0));
        }
    }

    override bool onMouseClick(int x, int y, int button, bool isDoubleClick, MouseState mstate)
    {
        // double-click => set to default
        if (isDoubleClick)
        {
            _param.setFromGUI(_param.defaultValue());
        }

        return true; // to initiate dragging
    }

    // Called when mouse drag this Element.
    override void onMouseDrag(int x, int y, int dx, int dy, MouseState mstate)
    {
        float displacementInHeight = cast(float)(dy) / _position.height; // TODO: replace by actual trail height instead of total height

        float modifier = 1.0f;
        if (mstate.shiftPressed || mstate.ctrlPressed)
            modifier *= 0.1f;

        double oldParamValue = _param.getNormalized();
        double newParamValue = oldParamValue - displacementInHeight * modifier * _sensivity;

        if (y > _mousePosOnLast0Cross)
            return;
        if (y < _mousePosOnLast1Cross)
            return;

        if (newParamValue <= 0 && oldParamValue > 0)
            _mousePosOnLast0Cross = y;

        if (newParamValue >= 1 && oldParamValue < 1)
            _mousePosOnLast1Cross = y;

        if (newParamValue < 0)
            newParamValue = 0;
        if (newParamValue > 1)
            newParamValue = 1;

        if (newParamValue > 0)
            _mousePosOnLast0Cross = float.infinity;

        if (newParamValue < 1)
            _mousePosOnLast1Cross = -float.infinity;

        if (newParamValue != oldParamValue)
            _param.setFromGUINormalized(newParamValue);
    }

    // For lazy updates
    override void onBeginDrag()
    {
        _param.beginParamEdit();
        setDirty();
    }

    override  void onStopDrag()
    {
        _param.endParamEdit();
        setDirty();
    }

    override void onMouseEnter()
    {
        setDirty();
    }

    override void onMouseExit()
    {
        setDirty();
    }

    override void onParameterChanged(Parameter sender) nothrow @nogc
    {
        setDirty();
    }

    override void onBeginParameterEdit(Parameter sender)
    {
    }

    override void onEndParameterEdit(Parameter sender)
    {
    }

protected:

    /// The parameter this switch is linked with.
    FloatParameter _param;

    /// Sensivity: given a mouse movement in 100th of the height of the knob,
    /// how much should the normalized parameter change.
    float _sensivity;

    bool _initialized; // destructor flag

    float _mousePosOnLast0Cross;
    float _mousePosOnLast1Cross;

    void clearCrosspoints()
    {
        _mousePosOnLast0Cross = float.infinity;
        _mousePosOnLast1Cross = -float.infinity;
    }
}
