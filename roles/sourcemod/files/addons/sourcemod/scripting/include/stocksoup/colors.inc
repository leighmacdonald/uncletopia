/**
 * Color function stocks.
 * Provides RGB and HSV methodmaps to work on color values packed into an integer.
 */

#if defined __stocksoup_colors_included
	#endinput
#endif

#define __stocksoup_colors_included

#pragma newdecls required

/**
 * 3 byte RGB color value packed into a 32-bit cell_t.
 */
methodmap RGBColor {
	public RGBColor(int r, int g, int b) {
		return view_as<RGBColor>( ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF) );
	}
	
	property int IntValue {
		public get() {
			return view_as<int>(this);
		}
	}
	
	property int Red {
		public get() {
			return (this.IntValue >> 16) & 0xFF;
		}
	}
	
	property int Green {
		public get() {
			return (this.IntValue >> 8) & 0xFF;
		}
	}
	
	property int Blue {
		public get() {
			return this.IntValue & 0xFF;
		}
	}
}

/**
 * 3 byte HSV color value packed into a 32-bit cell_t.
 */
methodmap HSVColor {
	public HSVColor(int h, int s, int v) {
		return view_as<HSVColor>( ((h & 0xFF) << 16) | ((s & 0xFF) << 8) | (v & 0xFF) );
	}
	
	property int IntValue {
		public get() {
			return view_as<int>(this);
		}
	}
	
	property int Hue {
		public get() {
			return (this.IntValue >> 16) & 0xFF;
		}
	}
	
	property int Saturation {
		public get() {
			return (this.IntValue >> 8) & 0xFF;
		}
	}
	
	property int Value {
		public get() {
			return this.IntValue & 0xFF;
		}
	}
}

/**
 * Converts an HSVColor value to an RGBColor value.
 * Based off of https://stackoverflow.com/a/14733008
 */
stock RGBColor HSVToRGB(HSVColor hsv) {
	if (!hsv.Saturation) {
		int value = hsv.Value;
		return RGBColor(value, value, value);
	}
	
	int region, remainder, p, q, r;
	
	region = hsv.Hue / 43;
	remainder = (hsv.Hue - (region * 43)) * 6;
	
	// four states: ascending (r), descending (q), const low (p), or const high (hsv.Value)
	// https://en.wikipedia.org/wiki/HSL_and_HSV#Converting_to_RGB
	p = (hsv.Value * (255 - hsv.Saturation)) >> 8;
	q = (hsv.Value * (255 - ((hsv.Saturation * remainder) >> 8))) >> 8;
	r = (hsv.Value * (255 - ((hsv.Saturation * (255 - remainder)) >> 8 ))) >> 8;
	
	switch (region) {
		case 0: {
			return RGBColor(hsv.Value, r, p);
		}
		case 1: {
			return RGBColor(q, hsv.Value, p);
		}
		case 2: {
			return RGBColor(p, hsv.Value, r);
		}
		case 3: {
			return RGBColor(p, q, hsv.Value);
		}
		case 4: {
			return RGBColor(r, p, hsv.Value);
		}
		case 5: {
			return RGBColor(hsv.Value, p, q);
		}
	}
	return RGBColor(0, 0, 0);
}

/**
 * Uses an approximation of David Merfield's Random Color generator to generate attractive
 * colors.
 * 
 * https://github.com/davidmerfield/randomColor
 */
stock RGBColor GetRandomColor() {
	return HSVToRGB(
		HSVColor(GetRandomInt(0, 255), GetRandomInt(140, 255), GetRandomInt(127, 255))
	);
}
