/**
 * A few additional handle-related functions.
 */

#if defined __stocksoup_handles_included
	#endinput
#endif

#define __stocksoup_handles_included

/**
 * Returns a clone of a handle with a new owner, deleting the existing one in the process.
 * The by-ref `hndl` argument is set to null.
 * 
 * The return type is `any` to allow assignment without retagging for Handle derivatives.
 */
stock any MoveHandle(Handle &hndl, Handle plugin = INVALID_HANDLE) {
	Handle moved = CloneHandle(hndl, plugin);
	delete hndl;
	return moved;
}

/**
 * Returns a clone of a handle with a new owner, deleting the existing one in the process.
 * 
 * This function is used for cases where the `hndl` argument is the return value of another
 * function call, in which case attempting to use `MoveHandle` results in an argument type
 * mismatch compile error.
 * 
 * The return type is `any` to allow assignment without retagging for Handle derivatives.
 */
stock any MoveHandleImmediate(Handle hndl, Handle plugin = INVALID_HANDLE) {
	Handle moved = CloneHandle(hndl, plugin);
	CloseHandle(hndl);
	return moved;
}
