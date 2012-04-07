//
// Flump - Copyright 2012 Three Rings Design

package flump.export {

import flash.utils.Dictionary;

import flump.SwfTexture;
import flump.display.Movie;
import flump.mold.KeyframeMold;
import flump.mold.LayerMold;
import flump.mold.MovieMold;
import flump.xfl.XflLibrary;
import flump.xfl.XflTexture;

import starling.display.DisplayObject;
import starling.display.Image;
import starling.display.Sprite;
import starling.textures.Texture;

import com.threerings.util.Map;
import com.threerings.util.Maps;

public class DisplayCreator
{
    public function DisplayCreator (lib :XflLibrary) {
        _lib = lib;
    }

    public function loadMovie (name :String) :Movie {
        return new Movie(_lib.getLibrary(name, MovieMold), _lib.frameRate, loadId);
    }

    public function getMemoryUsage (name :String, subtex :Dictionary = null) :int {
        if (name == null) return 0;
        if (FLIPBOOK_TEXTURE.exec(name) != null || _lib.getLibrary(name) is XflTexture) {
            const tex :Texture = getStarlingTexture(name);
            const usage :int = 4 * tex.width * tex.height;
            if (subtex != null && !subtex.hasOwnProperty(name)) {
                subtex[name] = usage;
            }
            return usage;
        }
        const xflMovie :MovieMold = _lib.getLibrary(name, MovieMold);
        if (subtex == null) subtex = new Dictionary();
        for each (var layer :LayerMold in xflMovie.layers) {
            for each (var kf :KeyframeMold in layer.keyframes) {
                getMemoryUsage(kf.id, subtex);
            }
        }
        var subtexUsage :int = 0;
        for (var texName :String in subtex) subtexUsage += subtex[texName];
        return subtexUsage;
    }

    /** Gets the maximum number of pixels drawn in a single frame by the given id. If it's
     * a texture, that's just the number of pixels in the texture. For a movie, it's the frame with
     * the largest set of textures present in its keyframe. For movies inside movies, the frame
     * drawn usage is the maximum that movie can draw. We're trying to get the worst case here.
     */
    public function getMaxDrawn (name :String) :int {
        if (name == null) return 0;
        if (FLIPBOOK_TEXTURE.exec(name) != null || _lib.getLibrary(name) is XflTexture) {
            const tex :Texture = getStarlingTexture(name);
            return tex.width * tex.height;
        }
        const xflMovie :MovieMold = _lib.getLibrary(name, MovieMold);
        var maxDrawn :int = 0;
        var calculatedKeyframes :Map = Maps.newMapOf(KeyframeMold);
        for (var ii :int = 0; ii < xflMovie.frames; ii++) {
            var drawn :int = 0;
            for each (var layer :LayerMold in xflMovie.layers) {
                var kf :KeyframeMold = layer.keyframeForFrame(ii);
                if (kf.visible) {
                    if (!calculatedKeyframes.containsKey(kf)) {
                        calculatedKeyframes.put(kf, getMaxDrawn(kf.id));
                    }
                    drawn += calculatedKeyframes.get(kf);
                }
            }
            maxDrawn = Math.max(maxDrawn, drawn);
        }
        return maxDrawn;
    }

    private function getStarlingTexture (name :String) :Texture {
        if (!_textures.hasOwnProperty(name)) {
            const match :Object = FLIPBOOK_TEXTURE.exec(name);
            var packed :SwfTexture;
            if (match == null)  {
                packed = SwfTexture.fromTexture(_lib.swf, _lib.getLibrary(name, XflTexture));
            } else {
                const movieName :String = match[1];
                const frame :int = int(match[2]);
                const movie :MovieMold = _lib.getLibrary(movieName, MovieMold);
                if (!movie.flipbook) {
                    throw new Error("Got non-flipbook movie for flipbook texture '" + name + "'");
                }
                packed = SwfTexture.fromFlipbook(_lib.swf, movie, frame);
            }
            _textures[name] = Texture.fromBitmapData(packed.toBitmapData());
            _textureOffsets[name] = packed.offset;
        }
        return _textures[name];
    }

    public function loadTexture (name :String) :DisplayObject {
        const image :Image = new Image(getStarlingTexture(name));
        image.x = _textureOffsets[name].x;
        image.y = _textureOffsets[name].y;
        const holder :Sprite = new Sprite();
        holder.addChild(image);
        return holder;
    }

    public function loadId (id :String) :DisplayObject {
        const match :Object = FLIPBOOK_TEXTURE.exec(id);
        if (match != null) return loadTexture(id);
        const libraryItem :* = _lib.getLibrary(id);
        if (libraryItem is XflTexture) return loadTexture(XflTexture(libraryItem).libraryItem);
        else return loadMovie(MovieMold(libraryItem).libraryItem);
    }

    protected const _textures :Dictionary = new Dictionary();// library name to Texture
    protected const _textureOffsets :Dictionary = new Dictionary();// library name to Point
    protected var _lib :XflLibrary;

    protected static const FLIPBOOK_TEXTURE :RegExp = /^(.*)_flipbook_(\d+)$/;
}
}
