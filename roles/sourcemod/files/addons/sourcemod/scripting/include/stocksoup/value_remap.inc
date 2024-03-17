#if defined __stocksoup_value_remap_included
	#endinput
#endif

#define __stocksoup_value_remap_included

/**
 * Remaps an input value such that the distance between it and its input bounds is proportional
 * to the output value and its output bounds.
 * 
 * Unless it's clamped, in which case the output value is clamped to the output bounds.
 * 
 * I can't figure out the proper term for this, so "remapping" it will have to do.
 */
stock float RemapValueFloat(float inputBounds[2], float outputBounds[2], float input,
		bool clamp = false) {
	float inputDelta, outputDelta, inputValueDelta, delta;
	
	inputDelta = inputBounds[1] - inputBounds[0];
	outputDelta = outputBounds[1] - outputBounds[0];
	
	inputValueDelta = (input - inputBounds[0]);
	delta = inputValueDelta / inputDelta;
	
	if (clamp) {
		delta = delta > 1.0 ? 1.0 : delta;
		delta = delta < 0.0 ? 0.0 : delta;
	}
	
	return outputBounds[0] + (outputDelta * delta);
}

/**
 * Wrapper for RemapValueFloat to deal with integer values.
 */
stock int RemapValue(int inputBounds[2], int outputBounds[2], int input, bool clamp = false) {
	float flInputBounds[2], flOutputBounds[2], flInput;
	
	flInputBounds[0] = float(inputBounds[0]);
	flInputBounds[1] = float(inputBounds[1]);
	
	flOutputBounds[0] = float(outputBounds[0]);
	flOutputBounds[1] = float(outputBounds[1]);
	
	flInput = float(input);
	
	return RoundFloat(RemapValueFloat(flInputBounds, flOutputBounds, flInput, clamp));
}