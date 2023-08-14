/*
Kvizzle
By F2


Features
- Supports having several KVs open simultaneously
- Pseudo-Classes (like :first-child, :nth-child(n), :any-child)
- Checks (like :has-value(val))
- Actions (like :count, :section-name)
- A traversal stack (with KvizJumpToKey, KvizGoBack and KvizRewind)
- Escaping in path (with backslash)
- Read from file and write to file



Public functions:

- KvizEscape(char[] dest, destLen, const char[] src)

- KeyValues KvizCreate(const char[] name)
- KeyValues KvizCreateFromFile(const char[] name, const char[] file)
- KeyValues KvizCreateFromString(const char[] name, const char[] data)
- bool KvizToFile(KeyValues kv, const char[] file, const char[] kvizPath = "", any ...)
- bool KvizClose(KeyValues kv) {

- bool KvizGetStringExact(KeyValues kv, char[] value, valueLen, const char[] path, any ...)
- bool KvizGetString(KeyValues kv, char[] value, valueLen, const char[] defVal, const char[] path, any ...)
- bool KvizSetString(KeyValues kv, const char[] value, const char[] path, any ...)

- bool KvizGetNumExact(KeyValues kv, &value, const char[] path, any ...)
- KvizGetNum(KeyValues kv, defVal, const char[] path, any ...)
- bool KvizSetNum(KeyValues kv, value, const char[] path, any ...)

- bool KvizGetFloatExact(KeyValues kv, &float value, const char[] path, any ...)
- float KvizGetFloat(KeyValues kv, float defVal, const char[] path, any ...)
- bool KvizSetFloat(KeyValues kv, float value, const char[] path, any ...)

- bool KvizGetVectorExact(KeyValues kv, float value[3], const char[] path, any ...)
- bool KvizGetVector(KeyValues kv, float vec[3], const float defVal[3], const char[] path, any ...)
- bool KvizSetVector(KeyValues kv, float vec[3], const char[] path, any ...)

- bool KvizGetColorExact(KeyValues kv, &r, &g, &b, &a, const char[] path, any ...)
- bool KvizGetColor(KeyValues kv, &r, &g, &b, &a, defR, defG, defB, defA, const char[] path, any ...)
- bool KvizSetColor(KeyValues kv, r, g, b, a, const char[] path, any ...)

- bool KvizGetUInt64Exact(KeyValues kv, value[2], const char[] path, any ...)
- bool KvizGetUInt64(KeyValues kv, value[2], const defVal[2], const char[] path, any ...)
- bool KvizSetUInt64(KeyValues kv, value[2], const char[] path, any ...)

- bool KvizDelete(KeyValues kv, const char[] path, any ...)

- bool KvizExists(KeyValues kv, const char[] path, any ...)

- bool KvizJumpToKey(KeyValues kv, bool create, const char[] path, any ...)
- bool KvizGoBack(KeyValues kv)
- bool KvizRewind(KeyValues kv)



TODO
- Write more comments in the code ;)
*/

#if defined _kvizzle_included
 #endinput
#endif
#define _kvizzle_included

#define KVIZZLE_VERSION     "1.1.0"

// Customizable settings
// Max number of simultaneously open Kvizzles. You can still use more, but the performance will degrade. However, if you set the number too high, then the performance will degrade when you have few Kvizzles opened simultaneously.
const int Kviz_iMaxContexts = 4;
// Max path depth... ie: aa.bb.cc.dd.ee(...).zz. Depth 32 equals 31 periods.
const int Kviz_iMaxPathDepth = 32;
// Max size of the traversal stack. The size of the traversal stack gets increased by 1 every time you call KvizJumpToKey, and decreased by 1 every time you call KvizGoBack. You can set it to 0 by calling KvizRewind.
#define Kviz_iMaxTraversalStack 32
// Max string length of a section in a Kv-file.
const int Kviz_iMaxSectionLen = 128;
// ---------------------



const int KVIZ_ACTION_NONE = 0;
// :first-child
const int KVIZ_PSEUDO_FIRSTCHILD = 10;
// :last-child
const int KVIZ_PSEUDO_LASTCHILD = 11;
// :nth-child
const int KVIZ_PSEUDO_NTHCHILD = 12;
// :any-child
const int KVIZ_PSEUDO_ANYCHILD = 13;
// :parent, :up
const int KVIZ_PSEUDO_UP = 14;

const int KVIZ_CHECK_MIN = 20;
// :has-value, :has-value(text)
const int KVIZ_CHECK_HASVALUE = 21;
// :has-value-ci, :has-value-ci(text)
const int KVIZ_CHECK_HASVALUE_CI = 22;
const KVIZ_CHECK_MAX = 29;

const KVIZ_ACTION_MIN = 30;
// :count
const KVIZ_ACTION_COUNT = 31;
// :section-name
const KVIZ_ACTION_SECTIONNAME = 32;
// :value
const KVIZ_ACTION_VALUE = 33;
// :value-or-section
const KVIZ_ACTION_VALUEORSECTION = 34;


enum struct KvizData {
    KeyValues Kviz_hKv;
    int Kviz_iPositionPathCount;

    int Kviz_iTraversalStack[Kviz_iMaxTraversalStack];
    int Kviz_iTraversalStackLen;

    int Kviz_iLRU;
}

KvizData Kviz[Kviz_iMaxContexts];
char Kviz_sPositionPath[Kviz_iMaxContexts][Kviz_iMaxPathDepth][Kviz_iMaxSectionLen];
char Kviz_sPositionPathPseudoClass[Kviz_iMaxContexts][Kviz_iMaxPathDepth][Kviz_iMaxSectionLen];
int Kviz_sPositionPathNthChild[Kviz_iMaxContexts][Kviz_iMaxPathDepth];
int Kviz_iCurrentContext = 0;
int Kviz_bInited = false;
StringMap Kviz_hPseudoClassTrie = null;
ArrayList Kviz_hArchiveKv;
ArrayList Kviz_hArchiveTraversalStack;
int Kviz_iLRUCounter = 0;




/**
 * Escapes a string, so it can be used in a Kvizzle path.
 *
 * @param dest      Buffer to store the escaped string in. Can be the same as src.
 * @param destLen   Length of dest.
 * @param src       Source string that needs to be escaped.
 * @noreturn
 */
stock void KvizEscape(char[] dest, int destLen, const char[] src) {
    char[] buffer = new char[destLen];
    int srcPos = 0;
    int destPos = 0;
    while (destPos + 1 < destLen && src[srcPos] != '\0') {
        if (src[srcPos] == ':' || src[srcPos] == '.') {
            buffer[destPos++] = '\\';
            if (destPos == destLen) {
                break;
            }
        }
        buffer[destPos++] = src[srcPos++];
    }
    buffer[destPos] = '\0';
    strcopy(dest, destLen, buffer);
}

/**
 * Creates an empty Kvizzle.
 *
 * @param name  The name of the root node.
 * @return      A new Kvizzle handle, or null in case of error.
 */
stock KeyValues KvizCreate(const char[] name) {
    if (!Kviz_bInited) {
        KvizInit();
    }

    KeyValues kv = new KeyValues(name);
    if (kv == null) {
        return null;
    }
    if (!KvizSwitchContext(kv, true)) {
        delete kv;
        return null;
    }
    return kv;
}

/**
 * Creates a Kvizzle based on a KeyValues file.
 *
 * @param name  The name of the root node.
 * @param file  The path for the KeyValues file.
 * @return      A new Kvizzle handle, or null in case of error.
 */
stock KeyValues KvizCreateFromFile(const char[] name, const char[] file) {
    if (!Kviz_bInited) {
        KvizInit();
    }

    KeyValues kv = new KeyValues(name);
    if (kv == null) {
        return null;
    }
    if (!kv.ImportFromFile(file)) {
        delete kv;
        return null;
    }
    if (!KvizSwitchContext(kv, true)) {
        delete kv;
        return null;
    }
    return kv;
}

/**
 * Creates a Kvizzle based on a string.
 *
 * @param name  The name of the root node.
 * @param data  The string containing the KeyValues data.
 * @return      A new Kvizzle handle, or null in case of error.
 */
stock KeyValues KvizCreateFromString(const char[] name, const char[] data) {
    if (!Kviz_bInited) {
        KvizInit();
    }

    KeyValues kv = KvizCreate(name);
    if (kv == null) {
        return null;
    }

    if (!kv.ImportFromString(data)) {
        KvizClose(kv);
        return null;
    }

    return kv;
}

/**
 * Saves the Kvizzle (using the given path as the root) to a file.
 *
 * @param kv        Kvizzle Handle.
 * @param file      Path to the file where the Kvizzle will be saved.
 * @param kvizPath  The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          A new Kvizzle handle, or null in case of error.
 * @error       Invalid Handle.
 */
stock bool KvizToFile(KeyValues kv, const char[] file, const char[] kvizPath = "", any ...) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char path2[256];
    VFormat(path2, sizeof(path2), kvizPath, 4);
    int action;
    if (!KvizGoto(kv, path2, false, action)) {
        return false;
    }

    return kv.ExportToFile(file);
}

/**
 * Closes the Kvizzle. Must be called once for every KvizCreate/KvizCreateFromFile.
 *
 * @param kv    Kvizzle Handle.
 * @return      True if the Kvizzle was open and is now closed. Otherwise false (eg. wrong handle, or it was already closed).
 * @error       Invalid Handle.
 */
stock bool KvizClose(KeyValues kv) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    // Roll back to the top. Otherwise, the next time a Kviz is opened with the same context id, it will think it has already traversed whatever position it is currently it. Fixed 09/07/2015.
    KvizRewind(kv);
    KvizRollBack(kv, -1);

    KvizRemoveContext(kv);
    delete kv;
    return true;
}


// ------------------
// Get/Set String
// ------------------

/**
 * Retrieves a string value from the Kvizzle.
 *
 * @param kv        Kvizzle Handle.
 * @param value     Buffer to store the string value.
 * @param valueLen  Length of the buffer.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True if the path existed and the string value was retrieved. Otherwise false.
 * @error           Invalid Handle.
 */
stock bool KvizGetStringExact(KeyValues kv, char[] value, int valueLen, const char[] path, any ...) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char path2[256];
    VFormat(path2, sizeof(path2), path, 5);
    int action;
    if (KvizGoto(kv, path2, false, action)) {
        switch (action) {
            case KVIZ_ACTION_NONE, KVIZ_ACTION_VALUE: {
                if (kv.GetDataType(NULL_STRING) == KvData_None) {
                    return false;
                } // We are at a section: "xyz" { ... }
                kv.GetString(NULL_STRING, value, valueLen);
                return true;
            }
            case KVIZ_ACTION_SECTIONNAME: {
                kv.GetSectionName(value, valueLen);
                return true;
            }
            case KVIZ_ACTION_COUNT: {
                LogError("Kvizzle - KvizGetString does not support :count (in %s)", path);
                return false;
            }
            default:
                LogError("Kvizzle - Unknown action: %s / %i", path, action);
        }
    }

    return false;
}

/**
 * Retrieves a string value from the Kvizzle, or the given default value if not found.
 *
 * @param kv        Kvizzle Handle.
 * @param value     Buffer to store the string value.
 * @param valueLen  Length of the buffer.
 * @param defVal    The default value to be used.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True if the path existed and the string value was retrieved. False if the default value was used.
 * @error           Invalid Handle.
 */
stock bool KvizGetString(KeyValues kv, char[] value, int valueLen, const char[] defVal, const char[] path, any ...) {
    char path2[256];
    VFormat(path2, sizeof(path2), path, 6);

    if (!KvizGetStringExact(kv, value, valueLen, "%s", path2)) {
        strcopy(value, valueLen, defVal);
        return false;
    }

    return true;
}

/**
 * Sets a string value in the Kvizzle at the given path. If the path does not exist, it is created.
 *
 * @param kv        Kvizzle Handle.
 * @param value     The value to be written.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True on succes. Otherwise false (eg. wrong handle).
 * @error           Invalid Handle.
 */
stock bool KvizSetString(KeyValues kv, const char[] value, const char[] path, any ...) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char path2[256];
    VFormat(path2, sizeof(path2), path, 4);
    int action;
    if (KvizGoto(kv, path2, true, action)) {
        if (action == KVIZ_ACTION_NONE || action == KVIZ_ACTION_VALUE) {
            kv.SetString(NULL_STRING, value);
            return true;
        }
        else if (action == KVIZ_ACTION_SECTIONNAME) {
            kv.SetSectionName(value);
            return true;
        }
        else {
            LogError("Kvizzle - KvizSetString does not support action %i (in %s)", action, path);
        }
    }
    return false;
}



// ------------------
// Get/Set Num
// ------------------

/**
 * Retrieves an integer value from the Kvizzle.
 *
 * @param kv        Kvizzle Handle.
 * @param value     Integer value, set by reference.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True if the path existed and its value was indeed an integer. Otherwise false.
 * @error           Invalid Handle.
 */
stock bool KvizGetNumExact(KeyValues kv, int &value, const char[] path, any ...) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char strvalue[64];

    char path2[256];
    VFormat(path2, sizeof(path2), path, 4);
    int action;
    if (KvizGoto(kv, path2, false, action)) {
        switch (action) {
            case KVIZ_ACTION_NONE, KVIZ_ACTION_VALUE: {
                if (kv.GetDataType(NULL_STRING) == KvData_None) {
                    return false;
                } // We are at a section: "xyz" { ... }
                kv.GetString(NULL_STRING, strvalue, sizeof(strvalue));
                if (StringToIntEx(strvalue, value) == strlen(strvalue)) {
                    return true;
                }
                return false;
            }
            case KVIZ_ACTION_SECTIONNAME: {
                kv.GetSectionName(strvalue, sizeof(strvalue));
                if (StringToIntEx(strvalue, value) == strlen(strvalue)) {
                    return true;
                }
                return false;
            }
            case KVIZ_ACTION_COUNT: {
                value = 0;
                if (kv.GotoFirstSubKey(false)) {
                    do {
                        value++;
                    } while (kv.GotoNextKey(false));
                    kv.GoBack();
                }

                return true;
            }
            default:
                LogError("Kvizzle - Unknown action: %s / %i", path, action);
        }
    }

    return false;
}

/**
 * Retrieves an integer value from the Kvizzle, or the default value if the path does not exist.
 *
 * @param kv        Kvizzle Handle.
 * @param defVal    The default value.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          The retrieved integer value, if the path existed. Otherwise, the default value.
 * @error           Invalid Handle.
 */
stock int KvizGetNum(KeyValues kv, int defVal, const char[] path, any ...) {
    char path2[256];
    VFormat(path2, sizeof(path2), path, 4);

    int value;
    if (!KvizGetNumExact(kv, value, "%s", path2)) {
        return defVal;
    }

    return value;
}

/**
 * Sets an integer value in the Kvizzle at the given path. If the path does not exist, it is created.
 *
 * @param kv        Kvizzle Handle.
 * @param value     The value to be written.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True on succes. Otherwise false (eg. wrong handle).
 * @error           Invalid Handle.
 */
stock bool KvizSetNum(KeyValues kv, int value, const char[] path, any ...) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char path2[256];
    VFormat(path2, sizeof(path2), path, 4);
    int action;
    if (KvizGoto(kv, path2, true, action)) {
        if (action == KVIZ_ACTION_NONE || action == KVIZ_ACTION_VALUE) {
            kv.SetNum(NULL_STRING, value);
            return true;
        }
        else if (action == KVIZ_ACTION_SECTIONNAME) {
            char strvalue[64];
            IntToString(value, strvalue, sizeof(strvalue));
            kv.SetSectionName(strvalue);
            return true;
        }
        else {
            LogError("Kvizzle - KvizSetNum does not support action %i (in %s)", action, path);
        }
    }
    return false;
}




// ------------------
// Get/Set UInt64
// ------------------

/**
 * Retrieves an UInt64 value from the Kvizzle.
 *
 * @param kv        Kvizzle Handle.
 * @param value     Buffer to store the UInt64 value.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True if the path existed and the UInt64 value was retrieved. Otherwise false.
 * @error           Invalid Handle.
 */
stock bool KvizGetUInt64Exact(KeyValues kv, int value[2], const char[] path, any ...) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char path2[256];
    VFormat(path2, sizeof(path2), path, 4);
    int action;
    if (KvizGoto(kv, path2, false, action)) {
        switch (action) {
            case KVIZ_ACTION_NONE, KVIZ_ACTION_VALUE: {
                if (kv.GetDataType(NULL_STRING) == KvData_None) {
                    return false;
                } // We are at a section: "xyz" { ... }
                // It turns out, KvGetUInt64 doesn't use the default value, if the kv-value is malformatted. In that case it just returns {0, 0}.
                kv.GetUInt64(NULL_STRING, value);
                return true;
            }
            case KVIZ_ACTION_SECTIONNAME:
                LogError("Kvizzle - KvizGetUInt64 does not support :section-name (in %s)", path);
            case KVIZ_ACTION_COUNT:
                LogError("Kvizzle - KvizGetUInt64 does not support :count (in %s)", path);
            default:
                LogError("Kvizzle - Unknown action: %s / %i", path, action);
        }
    }

    return false;
}

/**
 * Retrieves an UInt64 value from the Kvizzle, or the default value if the path does not exist.
 *
 * @param kv        Kvizzle Handle.
 * @param value     Buffer to store the UInt64 value.
 * @param defVal    Default value.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True if the path existed and the UInt64 value was retrieved. False if the default value was used.
 * @error           Invalid Handle.
 */
stock bool KvizGetUInt64(KeyValues kv, int value[2], const defVal[2], const char[] path, any ...) {
    char path2[256];
    VFormat(path2, sizeof(path2), path, 5);

    if (!KvizGetUInt64Exact(kv, value, "%s", path2)) {
        value[0] = defVal[0];
        value[1] = defVal[1];
        return false;
    }

    return true;
}

/**
 * Sets an UInt64 value in the Kvizzle at the given path. If the path does not exist, it is created.
 *
 * @param kv        Kvizzle Handle.
 * @param value     The value to be written.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True on succes. Otherwise false (eg. wrong handle).
 * @error           Invalid Handle.
 */
stock bool KvizSetUInt64(KeyValues kv, int value[2], const char[] path, any ...) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char path2[256];
    VFormat(path2, sizeof(path2), path, 4);
    int action;
    if (KvizGoto(kv, path2, true, action)) {
        if (action == KVIZ_ACTION_NONE || action == KVIZ_ACTION_VALUE) {
            kv.SetUInt64(NULL_STRING, value);
            return true;
        }
        else if (action == KVIZ_ACTION_SECTIONNAME)
            LogError("Kvizzle - KvizSetUInt64 does not support :section-name (in %s)", path);
        else {
            LogError("Kvizzle - KvizSetUInt64 does not support action %i (in %s)", action, path);
        }
    }
    return false;
}




// ------------------
// Get/Set Color
// ------------------

/**
 * Retrieves a color value from the Kvizzle.
 *
 * @param kv        Kvizzle Handle.
 * @param r         Red value, set by reference.
 * @param g         Green value, set by reference.
 * @param b         Blue value, set by reference.
 * @param a         Alpha value, set by reference.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True if the path existed and the color value was retrieved. Otherwise false.
 * @error           Invalid Handle.
 */
stock bool KvizGetColorExact(KeyValues kv, int &r, int &g, int &b, int &a, const char[] path, any ...) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char path2[256];
    VFormat(path2, sizeof(path2), path, 7);
    int action;
    if (KvizGoto(kv, path2, false, action)) {
        switch (action) {
            case KVIZ_ACTION_NONE, KVIZ_ACTION_VALUE: {
                if (kv.GetDataType(NULL_STRING) == KvData_None) {
                    return false;
                } // We are at a section: "xyz" { ... }
                kv.GetColor(NULL_STRING, r, g, b, a);
                return true;
            }
            case KVIZ_ACTION_SECTIONNAME:
                LogError("Kvizzle - KvizGetColor does not support :section-name (in %s)", path);
            case KVIZ_ACTION_COUNT:
                LogError("Kvizzle - KvizGetColor does not support :count (in %s)", path);
            default:
                LogError("Kvizzle - Unknown action: %s / %i", path, action);
        }
    }

    return false;
}

/**
 * Retrieves a color value from the Kvizzle, or the given default value if the path does not exist.
 *
 * @param kv        Kvizzle Handle.
 * @param r         Red value, set by reference.
 * @param g         Green value, set by reference.
 * @param b         Blue value, set by reference.
 * @param a         Alpha value, set by reference.
 * @param defR      Default red value.
 * @param defG      Default green value.
 * @param defB      Default blue value.
 * @param defA      Default alpha value.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True if the path existed and the color value was retrieved. False if the default values were used.
 * @error           Invalid Handle.
 */
stock bool KvizGetColor(KeyValues kv, int &r, int &g, int &b, int &a, int defR, int defG, int defB, int defA, const char[] path, any ...) {
    char path2[256];
    VFormat(path2, sizeof(path2), path, 11);

    if (!KvizGetColorExact(kv, r, g, b, a, "%s", path2)) {
        r = defR;
        g = defG;
        b = defB;
        a = defA;
        return false;
    }

    return true;
}

/**
 * Sets a color value in the Kvizzle at the given path. If the path does not exist, it is created.
 *
 * @param kv        Kvizzle Handle.
 * @param r         Red value.
 * @param g         Green value.
 * @param b         Blue value.
 * @param a         Alpha value.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True on succes. Otherwise false (eg. wrong handle).
 * @error           Invalid Handle.
 */
stock bool KvizSetColor(KeyValues kv, int r, int g, int b, int a, const char[] path, any ...) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char path2[256];
    VFormat(path2, sizeof(path2), path, 7);
    int action;
    if (KvizGoto(kv, path2, true, action)) {
        if (action == KVIZ_ACTION_NONE || action == KVIZ_ACTION_VALUE) {
            kv.SetColor(NULL_STRING, r, g, b, a);
            return true;
        }
        else if (action == KVIZ_ACTION_SECTIONNAME) {
            char strvalue[64];
            FormatEx(strvalue, sizeof(strvalue), "%i %i %i %i", r, g, b, a);
            kv.SetSectionName(strvalue);
            return true;
        }
        else {
            LogError("Kvizzle - KvizSetColor does not support action %i (in %s)", action, path);
        }
    }
    return false;
}





// ------------------
// Get/Set Float
// ------------------

/**
 * Retrieves a float value from the Kvizzle.
 *
 * @param kv        Kvizzle Handle.
 * @param value     The retrieved float value, set by reference.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True if the path existed and the retrieved value was indeed a float. Otherwise false.
 * @error           Invalid Handle.
 */
stock bool KvizGetFloatExact(KeyValues kv, float &value, const char[] path, any ...) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char strvalue[64];

    char path2[256];
    VFormat(path2, sizeof(path2), path, 4);
    int action;
    if (KvizGoto(kv, path2, false, action)) {
        switch (action) {
            case KVIZ_ACTION_NONE, KVIZ_ACTION_VALUE: {
                if (kv.GetDataType(NULL_STRING) == KvData_None) {
                    return false;
                } // We are probably at a section: "xyz" { ... }
                kv.GetString(NULL_STRING, strvalue, sizeof(strvalue));
                if (StringToFloatEx(strvalue, value) == strlen(strvalue)) {
                    return true;
                }
                return false;
            }
            case KVIZ_ACTION_SECTIONNAME: {
                kv.GetSectionName(strvalue, sizeof(strvalue));
                if (StringToFloatEx(strvalue, value) == strlen(strvalue)) {
                    return true;
                }
                return false;
            }
            case KVIZ_ACTION_COUNT:
                LogError("Kvizzle - KvizGetFloat does not support :count (in %s)", path);
            default:
                LogError("Kvizzle - Unknown action: %s / %i", path, action);
        }
    }

    return false;
}

/**
 * Retrieves a float value from the Kvizzle, or the given default value if the path does not exist.
 *
 * @param kv        Kvizzle Handle.
 * @param defVal    The default value.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          Returns the retrieved float value, or the default value if the path does not exist.
 * @error           Invalid Handle.
 */
stock float KvizGetFloat(KeyValues kv, float defVal, const char[] path, any ...) {
    char path2[256];
    VFormat(path2, sizeof(path2), path, 4);

    float value;
    if (!KvizGetFloatExact(kv, value, "%s", path2)) {
        return defVal;
    }

    return value;
}

/**
 * Sets a float value in the Kvizzle at the given path. If the path does not exist, it is created.
 *
 * @param kv        Kvizzle Handle.
 * @param value     The value to be written.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True on succes. Otherwise false (eg. wrong handle).
 * @error           Invalid Handle.
 */
stock bool KvizSetFloat(KeyValues kv, float value, const char[] path, any ...) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char path2[256];
    VFormat(path2, sizeof(path2), path, 4);
    int action;
    if (KvizGoto(kv, path2, true, action)) {
        if (action == KVIZ_ACTION_NONE || action == KVIZ_ACTION_VALUE) {
            kv.SetFloat(NULL_STRING, value);
            return true;
        }
        else if (action == KVIZ_ACTION_SECTIONNAME) {
            char strvalue[64];
            FloatToString(value, strvalue, sizeof(strvalue));
            kv.SetSectionName(strvalue);
            return true;
        }
        else {
            LogError("Kvizzle - KvizSetFloat does not support action %i (in %s)", action, path);
        }
    }
    return false;
}




// ------------------
// Get/Set Vector
// ------------------

/**
 * Retrieves a vector value from the Kvizzle.
 *
 * @param kv        Kvizzle Handle.
 * @param value     Buffer to store the vector value.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True if the path existed and the vector value was retrieved. Otherwise false.
 * @error           Invalid Handle.
 */
stock bool KvizGetVectorExact(KeyValues kv, float value[3], const char[] path, any ...) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char strvalue[64];

    char path2[256];
    VFormat(path2, sizeof(path2), path, 4);
    int action;
    if (KvizGoto(kv, path2, false, action)) {
        switch (action) {
            case KVIZ_ACTION_NONE, KVIZ_ACTION_VALUE: {
                if (kv.GetDataType(NULL_STRING) == KvData_None) {
                    return false;
                } // We are at a section: "xyz" { ... }
                kv.GetString(NULL_STRING, strvalue, sizeof(strvalue));
                if (KvizStringToVector(strvalue, value)) {
                    return true;
                }
                return false;
            }
            case KVIZ_ACTION_SECTIONNAME: {
                kv.GetSectionName(strvalue, sizeof(strvalue));
                if (KvizStringToVector(strvalue, value)) {
                    return true;
                }
                return false;
            }
            case KVIZ_ACTION_COUNT:
                LogError("Kvizzle - KvizGetFloat does not support :count (in %s)", path);
            default:
                LogError("Kvizzle - Unknown action: %s / %i", path, action);
        }
    }

    return false;
}

/**
 * Retrieves a vector value from the Kvizzle, or the default value if the path does not exist.
 *
 * @param kv        Kvizzle Handle.
 * @param value     Buffer to store the vector value.
 * @param defVal    The default value.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True if the path existed and the vector value was retrieved. False if the default value was used.
 * @error           Invalid Handle.
 */
stock bool KvizGetVector(KeyValues kv, float vec[3], const float defVal[3], const char[] path, any ...) {
    char path2[256];
    VFormat(path2, sizeof(path2), path, 5);

    if (!KvizGetVectorExact(kv, vec, "%s", path2)) {
        vec[0] = defVal[0];
        vec[1] = defVal[1];
        vec[2] = defVal[2];
        return false;
    }

    return true;
}

/**
 * Sets a vector value in the Kvizzle at the given path. If the path does not exist, it is created.
 *
 * @param kv        Kvizzle Handle.
 * @param vec       The value to be written.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True on succes. Otherwise false (eg. wrong handle).
 * @error           Invalid Handle.
 */
stock bool KvizSetVector(KeyValues kv, float vec[3], const char[] path, any ...) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char path2[256];
    VFormat(path2, sizeof(path2), path, 4);
    int action;
    if (KvizGoto(kv, path2, true, action)) {
        if (action == KVIZ_ACTION_NONE || action == KVIZ_ACTION_VALUE) {
            kv.SetVector(NULL_STRING, vec);
            return true;
        }
        else if (action == KVIZ_ACTION_SECTIONNAME) {
            char strvalue[Kviz_iMaxSectionLen];
            Format(strvalue, sizeof(strvalue), "%f %f %f", vec[0], vec[1], vec[2]);
            kv.SetSectionName(strvalue);
            return true;
        }
        else {
            LogError("Kvizzle - KvizSetVector does not support action %i (in %s)", action, path);
        }
    }
    return false;
}




/**
 * Deletes a node at the given path.
 *
 * @param kv        Kvizzle Handle.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True if the node was found and deleted. Otherwise false.
 * @error           Invalid Handle.
 */
stock bool KvizDelete(KeyValues kv, const char[] path, any ...) {
    // NOTE: Be aware that when you delete something, the value of a pseudo-class might change. In that case, we will need to remove that pseudo-class from the path stack. However, for first-child, last-child and nth-child it is not a problem. any-child and parent are not saved on the path stack.

    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char path2[256];
    VFormat(path2, sizeof(path2), path, 3);
    int action;
    if (!KvizGoto(kv, path2, false, action) || action != KVIZ_ACTION_NONE) {
        return false;
    }

    int ret = kv.DeleteThis();
    //PrintToServer("Delete=%i", ret);
    if (ret == 1) {
        int pathDepth = Kviz[Kviz_iCurrentContext].Kviz_iPositionPathCount - 1;
        kv.GetSectionName(Kviz_sPositionPath[Kviz_iCurrentContext][pathDepth], sizeof(Kviz_sPositionPath[][]));
        //Kviz_sPositionPathPseudoClass[Kviz_iCurrentContext][pathDepth][0] = '\0';
        //PrintToServer("section  %s", Kviz_sPositionPath[Kviz_iCurrentContext][pathDepth]);
        return true;
    }
    else if (ret == -1) {
        Kviz[Kviz_iCurrentContext].Kviz_iPositionPathCount--;
        return true;
    }
    else {
        return false;
    }
}

/**
 * Jump to a key in the Kvizzle. All subsequent calls to Kv* will be relative to this path, until KvizGoBack is called.
 *
 * @note            This adds to the internal traversal stack.
 * @param kv        Kvizzle Handle.
 * @param create    If set to true, the path will be created if it does not exist.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True if the jump was successful. Otherwise false (eg. when create is false and the path does not exist).
 * @error           Invalid Handle.
 */
stock bool KvizJumpToKey(KeyValues kv, bool create, const char[] path, any ...) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char path2[256];
    VFormat(path2, sizeof(path2), path, 4);

    int action;
    if (!KvizGoto(kv, path2, create, action, true) || action != KVIZ_ACTION_NONE) {
        return false;
    }

    Kviz[Kviz_iCurrentContext].Kviz_iTraversalStack[Kviz[Kviz_iCurrentContext].Kviz_iTraversalStackLen] = Kviz[Kviz_iCurrentContext].Kviz_iPositionPathCount;
    Kviz[Kviz_iCurrentContext].Kviz_iTraversalStackLen++;
    return true;
}

/**
 * Pops one element off the traversal stack. Should be used together with KvizJumpToKey.
 *
 * @param kv        Kvizzle Handle.
 * @return          True if an element was popped off the traversal stack. False if the traversal stack was empty.
 * @error           Invalid Handle.
 */
stock bool KvizGoBack(KeyValues kv) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    if (Kviz[Kviz_iCurrentContext].Kviz_iTraversalStackLen == 0) {
        return false;
    }

    Kviz[Kviz_iCurrentContext].Kviz_iTraversalStackLen--;
    return true;
}

/**
 * Rewinds the traversal stack.
 *
 * @param kv        Kvizzle Handle.
 * @return          True if the traversal stack was successfully rewinded. Otherwise false (eg. wrong handle).
 * @error           Invalid Handle.
 */
stock bool KvizRewind(KeyValues kv) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    while (KvizGoBack(kv)) { }
    return true;
}

/**
 * Checks if a Kvizzle path exists.
 *
 * @param kv        Kvizzle Handle.
 * @param path      The Kvizzle path to be formatted.
 * @param ...       Variable number of format parameters.
 * @return          True if the path exists. Otherwise false.
 * @error           Invalid Handle.
 */
stock bool KvizExists(KeyValues kv, const char[] path, any ...) {
    if (!KvizSwitchContext(kv)) {
        return false;
    }

    char path2[256];
    VFormat(path2, sizeof(path2), path, 3);

    int action;
    if (KvizGoto(kv, path2, false, action)) {
        if (action != KVIZ_ACTION_NONE) {
            LogError("Kvizzle - KvizExists doesn't support actions (%s)", path);
        }

        return true;
    }

    return false;
}

// An alias for KvizExists
stock bool KvizExist(KeyValues kv, const char[] path, any ...) {
    char path2[256];
    VFormat(path2, sizeof(path2), path, 3);

    return KvizExists(kv, "%s", path2);
}







// ------------------
// Private functions
// ------------------

stock void KvizInit() {
    if (Kviz_bInited) {
        return;
    }
    Kviz_bInited = true;

    Kviz_hPseudoClassTrie = new StringMap();
    Kviz_hPseudoClassTrie.SetValue(":first-child", KVIZ_PSEUDO_FIRSTCHILD);
    Kviz_hPseudoClassTrie.SetValue(":last-child", KVIZ_PSEUDO_LASTCHILD);
    Kviz_hPseudoClassTrie.SetValue(":nth-child", KVIZ_PSEUDO_NTHCHILD);
    Kviz_hPseudoClassTrie.SetValue(":any-child", KVIZ_PSEUDO_ANYCHILD);
    Kviz_hPseudoClassTrie.SetValue(":up", KVIZ_PSEUDO_UP);
    Kviz_hPseudoClassTrie.SetValue(":parent", KVIZ_PSEUDO_UP);

    Kviz_hPseudoClassTrie.SetValue(":has-value", KVIZ_CHECK_HASVALUE);
    Kviz_hPseudoClassTrie.SetValue(":has-value-ci", KVIZ_CHECK_HASVALUE_CI);

    Kviz_hPseudoClassTrie.SetValue(":count", KVIZ_ACTION_COUNT);
    Kviz_hPseudoClassTrie.SetValue(":section-name", KVIZ_ACTION_SECTIONNAME);
    Kviz_hPseudoClassTrie.SetValue(":key", KVIZ_ACTION_SECTIONNAME);
    Kviz_hPseudoClassTrie.SetValue(":value", KVIZ_ACTION_VALUE);
    Kviz_hPseudoClassTrie.SetValue(":value-or-section", KVIZ_ACTION_VALUEORSECTION);

    Kviz_hArchiveKv = new ArrayList();
    Kviz_hArchiveTraversalStack = new ArrayList(Kviz_iMaxTraversalStack+1);
}


stock bool KvizGoto(KeyValues kv, const char[] path, bool create, int &action, bool jumpToValues = true, int depth = 0) {
    action = KVIZ_ACTION_NONE;
    if (path[0] == '\0') {
        // Go to root
        int rootDepth = -1;
        if (Kviz[Kviz_iCurrentContext].Kviz_iTraversalStackLen != 0) {
            rootDepth = Kviz[Kviz_iCurrentContext].Kviz_iTraversalStack[Kviz[Kviz_iCurrentContext].Kviz_iTraversalStackLen - 1] - 1;
        }
        KvizRollBack(kv, rootDepth);
        return true;
    }
    else if (Kviz[Kviz_iCurrentContext].Kviz_iTraversalStackLen != 0) {
        return KvizGoto2(kv, path, create, action, jumpToValues, Kviz[Kviz_iCurrentContext].Kviz_iTraversalStack[Kviz[Kviz_iCurrentContext].Kviz_iTraversalStackLen - 1]);
    }
    else {
        return KvizGoto2(kv, path, create, action, jumpToValues, 0);
    }
}

stock bool KvizGoto2(KeyValues kv, const char[] path, bool create, int &action, bool jumpToValues, int depth) {
    char key[Kviz_iMaxSectionLen];
    int endPos = 0;
    int destPos = 0;
    while (path[endPos] != '.' && path[endPos] != '\0' && !(path[endPos] == ':' && endPos != 0)) {
        if (path[endPos] == '\\') {
            if (path[endPos+1] == '\0') {
                key[destPos++] = path[endPos++];
            }
            else {
                endPos++;
                key[destPos++] = path[endPos++];
            }
        }
        else {
            key[destPos++] = path[endPos++];
        }
    }

    if (endPos == 0) {
        return false;
    }

    key[destPos] = '\0';

    bool isPseudoClass = key[0] == ':';
    bool isAction = false;
    bool isCheck = false;
    int pseudoClass;
    char pseudoClassTag[128];
    char pseudoClassParms[128];
    bool pseudoClassHasParm = false;
    int pseudoParmInt;

    if (isPseudoClass) {
        int pseudoClassParmsLen = 0;
        int pseudoClassTagLen = 0;
        for (int i = 0; i < sizeof(key) && key[i] != '\0'; i++) {
            if (key[i] == '(') {
                pseudoClassHasParm = true;
                key[i] = '\0';
            }
            else if (pseudoClassHasParm) {
                if (key[i] == ')') {
                    break;
                }
                else {
                    pseudoClassParms[pseudoClassParmsLen++] = key[i];
                }
            }
            else {
                pseudoClassTag[i] = key[i];
                pseudoClassTagLen++;
            }
        }
        pseudoClassTag[pseudoClassTagLen] = '\0';
        pseudoClassParms[pseudoClassParmsLen] = '\0';

        if (!Kviz_hPseudoClassTrie.GetValue(pseudoClassTag, pseudoClass)) {
            LogError("Kvizzle - Unknown pseudo class: %s", key);
            return false;
        }

        if (pseudoClassParmsLen != 0) {
            pseudoParmInt = StringToInt(pseudoClassParms);
        }

        if (pseudoClass == KVIZ_PSEUDO_FIRSTCHILD) {
            pseudoClassTag = "nth-child";
            pseudoClass = KVIZ_PSEUDO_NTHCHILD;
            pseudoParmInt = 1;
            strcopy(key, sizeof(key), "nth-child(1)");
        }

        isAction = pseudoClass >= KVIZ_ACTION_MIN;
        isCheck = pseudoClass >= KVIZ_CHECK_MIN && pseudoClass <= KVIZ_CHECK_MAX;
    }

    bool alreadyInPosition = false;
    if (isAction) {
        alreadyInPosition = true;
        // We are not going any deeper in this step.
        depth--;
    }
    else if (isCheck) {
        alreadyInPosition = true;
        // We are not going any deeper in this step.
        depth--;
    }
    else {
        if (isPseudoClass && pseudoClass == KVIZ_PSEUDO_UP) {
            int rootDepth = -1;
            int traversalStackLen = Kviz[Kviz_iCurrentContext].Kviz_iTraversalStackLen;
            if (traversalStackLen != 0) {
                rootDepth = Kviz[Kviz_iCurrentContext].Kviz_iTraversalStack[traversalStackLen - 1] - 1;
            }
            alreadyInPosition = true;
            depth -= 2;
            if (depth < rootDepth) {
                LogError("Kvizzle - :up used on root node (%s)", path);
                depth = rootDepth;
            }
        }
        else if (depth < Kviz[Kviz_iCurrentContext].Kviz_iPositionPathCount) {
            if (isPseudoClass) {
                if (pseudoClass == KVIZ_PSEUDO_NTHCHILD && Kviz_sPositionPathNthChild[Kviz_iCurrentContext][depth] != 0) {
                    int currentChildNum = Kviz_sPositionPathNthChild[Kviz_iCurrentContext][depth];
                    int newChildNum = pseudoParmInt;
                    if (currentChildNum == newChildNum) {
                        alreadyInPosition = true;
                    }
                    else if (currentChildNum < newChildNum) {
                        KvizRollBack(kv, depth);
                        while (currentChildNum < newChildNum) {
                            if (!kv.GotoNextKey(!jumpToValues)) {
                                //PrintToServer("Fast nth-child: Not found - setting to :nth-child(%i)", currentChildNum);
                                kv.GetSectionName(Kviz_sPositionPath[Kviz_iCurrentContext][depth], sizeof(Kviz_sPositionPath[][]));
                                Format(Kviz_sPositionPathPseudoClass[Kviz_iCurrentContext][depth], sizeof(Kviz_sPositionPathPseudoClass[][]), ":nth-child(%i)", currentChildNum);
                                Kviz_sPositionPathNthChild[Kviz_iCurrentContext][depth] = currentChildNum;
                                return false;
                            }
                            currentChildNum++;
                            //PrintToServer("Fast nth-child: GotoNextKey(%i)", currentChildNum);
                        }
                        kv.GetSectionName(Kviz_sPositionPath[Kviz_iCurrentContext][depth], sizeof(Kviz_sPositionPath[][]));
                        strcopy(Kviz_sPositionPathPseudoClass[Kviz_iCurrentContext][depth], sizeof(Kviz_sPositionPathPseudoClass[][]), key);
                        Kviz_sPositionPathNthChild[Kviz_iCurrentContext][depth] = currentChildNum;
                        alreadyInPosition = true;
                    }
                    else {
                        KvizRollBack(kv, depth-1);
                    }
                }
                else if (pseudoClass != KVIZ_PSEUDO_ANYCHILD && StrEqual(Kviz_sPositionPathPseudoClass[Kviz_iCurrentContext][depth], key)) {
                    alreadyInPosition = true;
                }
                else {
                    KvizRollBack(kv, depth-1);
                }
            }
            else {
                if (StrEqual(Kviz_sPositionPath[Kviz_iCurrentContext][depth], key)) {
                    alreadyInPosition = true;
                }
                else {
                    KvizRollBack(kv, depth-1);
                }
            }
        }
    }

    if (!alreadyInPosition) {
        if (isPseudoClass) {
            switch (pseudoClass) {
                case KVIZ_PSEUDO_LASTCHILD: {
                    //PrintToServer("Go to last child");
                    if (!kv.GotoFirstSubKey(!jumpToValues)) {
                        return false;
                    }
                    while (kv.GotoNextKey(!jumpToValues)) { }

                    kv.GetSectionName(Kviz_sPositionPath[Kviz_iCurrentContext][depth], sizeof(Kviz_sPositionPath[][]));
                    strcopy(Kviz_sPositionPathPseudoClass[Kviz_iCurrentContext][depth], sizeof(Kviz_sPositionPathPseudoClass[][]), key);
                    Kviz_sPositionPathNthChild[Kviz_iCurrentContext][depth] = 0;
                    Kviz[Kviz_iCurrentContext].Kviz_iPositionPathCount++;
                }
                case KVIZ_PSEUDO_NTHCHILD: {
                    //PrintToServer("Go to %ith child", pseudoParmInt);
                    if (!kv.GotoFirstSubKey(!jumpToValues)) {
                        return false;
                    }

                    int currentChildNum = 0;
                    bool childFound = false;
                    do {
                        currentChildNum++;
                        if (currentChildNum == pseudoParmInt) {
                            childFound = true;
                            break;
                        }
                    } while (kv.GotoNextKey(!jumpToValues));

                    if (!childFound) {
                        kv.GetSectionName(Kviz_sPositionPath[Kviz_iCurrentContext][depth], sizeof(Kviz_sPositionPath[][]));
                        Format(Kviz_sPositionPathPseudoClass[Kviz_iCurrentContext][depth], sizeof(Kviz_sPositionPathPseudoClass[][]), ":nth-child(%i)", currentChildNum);
                        Kviz_sPositionPathNthChild[Kviz_iCurrentContext][depth] = currentChildNum;
                        Kviz[Kviz_iCurrentContext].Kviz_iPositionPathCount++;
                        return false;
                    }

                    kv.GetSectionName(Kviz_sPositionPath[Kviz_iCurrentContext][depth], sizeof(Kviz_sPositionPath[][]));
                    strcopy(Kviz_sPositionPathPseudoClass[Kviz_iCurrentContext][depth], sizeof(Kviz_sPositionPathPseudoClass[][]), key);
                    Kviz_sPositionPathNthChild[Kviz_iCurrentContext][depth] = pseudoParmInt;
                    Kviz[Kviz_iCurrentContext].Kviz_iPositionPathCount++;
                }
                case KVIZ_PSEUDO_ANYCHILD: {
                    if (!kv.GotoFirstSubKey(!jumpToValues)) {
                        return false;
                    }

                    Kviz[Kviz_iCurrentContext].Kviz_iPositionPathCount++;

                    int currentChildNum = 0;
                    do {
                        currentChildNum++;

                        // We must set the position path values before calling KvGoto recursively. This is because :up should be able to overwrite the values.
                        kv.GetSectionName(Kviz_sPositionPath[Kviz_iCurrentContext][depth], sizeof(Kviz_sPositionPath[][]));
                        Format(Kviz_sPositionPathPseudoClass[Kviz_iCurrentContext][depth], sizeof(Kviz_sPositionPathPseudoClass[][]), ":nth-child(%i)", currentChildNum);
                        Kviz_sPositionPathNthChild[Kviz_iCurrentContext][depth] = currentChildNum;

                        if (path[endPos] == '\0') {
                            KvizRollBack(kv, depth);
                            return true;
                        }

                        if (KvizGoto2(kv, path[path[endPos] == ':' ? endPos : endPos+1], create, action, jumpToValues, depth + 1)) {
                            return true;
                        }

                        KvizRollBack(kv, depth);
                    } while (kv.GotoNextKey(!jumpToValues));

                    return false;
                }
                default:
                    KvizThrowError(kv, "Unknown pseudoClass (%s / %i) - Please contact F2", key, pseudoClass);
            }
        }
        else {
            //PrintToServer("JumpToKey: %s", key);
            if (!kv.JumpToKey(key, create)) {
                return false;
            }

            strcopy(Kviz_sPositionPath[Kviz_iCurrentContext][depth], sizeof(Kviz_sPositionPath[][]), key);
            Kviz_sPositionPathPseudoClass[Kviz_iCurrentContext][depth][0] = '\0';
            Kviz[Kviz_iCurrentContext].Kviz_iPositionPathCount++;
            // We jumped directly to a subkey - we don't know which number child it is. Fixed 06/07/2015.
            Kviz_sPositionPathNthChild[Kviz_iCurrentContext][depth] = 0;
        }
    }
    else if (isAction) {
        action = pseudoClass;
    }
    else if (isCheck) {
        switch (pseudoClass) {
            case KVIZ_CHECK_HASVALUE, KVIZ_CHECK_HASVALUE_CI: {
                if (kv.GetDataType(NULL_STRING) == KvData_None) {
                    return false;
                }

                if (pseudoClassHasParm) {
                    // :has-value .. check that the node has the specified string value
                    char strvalue[256];
                    kv.GetString(NULL_STRING, strvalue, sizeof(strvalue));
                    if (!StrEqual(strvalue, pseudoClassParms, pseudoClass == KVIZ_CHECK_HASVALUE)) {
                        return false;
                    }
                }
                else {
                    // :has-value .. check that the node has a value (ie. it is not a section)
                    // --- we already did that above.
                }
            }
            default:
                KvizThrowError(kv, "Unknown pseudoClass (%s / %i) - Please contact F2", key, pseudoClass);
        }
    }

    if (path[endPos] == '\0') {
        // If we were in "A.B.C" before, and we are now navigating to "A.B", then make sure to remove "C" from the stack.
        KvizRollBack(kv, depth);

        if (action == KVIZ_ACTION_VALUEORSECTION) {
            KvDataTypes dataType = kv.GetDataType(NULL_STRING);
            if (dataType == KvData_None) {
                action = KVIZ_ACTION_SECTIONNAME;
            }
            else {
                action = KVIZ_ACTION_VALUE;
            }
        }
        return true;
    }

    if (action != KVIZ_ACTION_NONE) {
        return false;
    } // You cannot use an action in the middle of a path

    if (!KvizGoto2(kv, path[path[endPos] == ':' ? endPos : endPos+1], create, action, jumpToValues, depth + 1)) {
        return false;
    }

    return true;
}

stock void KvizRollBack(KeyValues kv, int destPos) {
    while (Kviz[Kviz_iCurrentContext].Kviz_iPositionPathCount > destPos+1) {
        //PrintToServer("GoBack");
        kv.GoBack();
        Kviz[Kviz_iCurrentContext].Kviz_iPositionPathCount--;
    }
}

stock bool KvizStringToVector(const char[] strvalue, float vec[3]) {
    int pos = 0;
    int consumed = StringToFloatEx(strvalue, vec[0]);
    if (consumed == 0 || strvalue[consumed] == '\0') {
        //PrintToServer("StringToVector - fail 1");
        return false;
    }
    pos = consumed+1;
    consumed = StringToFloatEx(strvalue[pos], vec[1]);
    if (consumed == 0 || strvalue[pos+consumed] == '\0') {
        //PrintToServer("StringToVector - fail 2");
        return false;
    }
    pos += consumed+1;
    consumed = StringToFloatEx(strvalue[pos], vec[2]);
    if (consumed > 0 && strvalue[pos+consumed] == '\0') {
        return true;
    }
    //PrintToServer("StringToVector - fail 3");
    return false;
}

stock void KvizResetContext(int context) {
    Kviz[context].Kviz_hKv = null;
    Kviz[context].Kviz_iPositionPathCount = 0;
    Kviz[context].Kviz_iTraversalStackLen = 0;
}

stock bool KvizSwitchContext(KeyValues kv, bool mayCreate = false) {
    if (kv == null) {
        KvizThrowError(kv, "kv was null.");
    }

    for (int i = 0; i < Kviz_iMaxContexts; i++) {
        if (Kviz[Kviz_iCurrentContext].Kviz_hKv == kv) {
            Kviz[Kviz_iCurrentContext].Kviz_iLRU = ++Kviz_iLRUCounter;
            return true;
        }

        Kviz_iCurrentContext++;
        if (Kviz_iCurrentContext == Kviz_iMaxContexts) {
            Kviz_iCurrentContext = 0;
        }
    }

    if (KvizSwitchFromArchive(kv)) {
        Kviz[Kviz_iCurrentContext].Kviz_iLRU = ++Kviz_iLRUCounter;
        return true;
    }

    if (!mayCreate) {
        LogError("Kvizzle - kv not found. Remember to call KvizCreate first!");
        return false;
    }

    Kviz_iCurrentContext = KvizGetFreeContext();
    Kviz[Kviz_iCurrentContext].Kviz_hKv = kv;
    Kviz[Kviz_iCurrentContext].Kviz_iLRU = ++Kviz_iLRUCounter;
    return true;
}

stock bool KvizSwitchFromArchive(KeyValues kv) {
    int archiveLen = Kviz_hArchiveKv.Length;
    for (int i = 0; i < archiveLen; i++) {
        KeyValues archiveKv = view_as<KeyValues>(Kviz_hArchiveKv.Get(i));
        if (archiveKv == kv) {
            int context = KvizGetFreeContext();

            char path[Kviz_iMaxPathDepth][Kviz_iMaxSectionLen];

            int pathPos = 0;
            for (int kvDepth = kv.NodesInStack(); kvDepth > 0; kvDepth = kv.GoBack() ? kvDepth - 1 : 0) {
                kv.GetSectionName(path[pathPos], sizeof(path[]));
                pathPos++;
            }

            char kvizPos[Kviz_iMaxPathDepth*Kviz_iMaxSectionLen] = "";
            if (pathPos > 0) {
                // TODO: Can be optimized a lot, because StrCat is getting strlen all the time
                pathPos--;
                strcopy(kvizPos, sizeof(kvizPos), path[pathPos]);
                for (pathPos--; pathPos >= 0; pathPos--) {
                    StrCat(kvizPos, sizeof(kvizPos), ".");
                    KvizEscape(path[pathPos], sizeof(path[]), path[pathPos]);
                    StrCat(kvizPos, sizeof(kvizPos), path[pathPos]);
                }
            }

            Kviz_iCurrentContext = context;
            Kviz[context].Kviz_hKv = kv;
            Kviz[context].Kviz_iPositionPathCount = 0;
            Kviz[context].Kviz_iTraversalStackLen = 0;
            if (!StrEqual("", kvizPos)) {
                int action;
                if (!KvizGoto(kv, kvizPos, false, action)) {
                    KvizThrowError(kv, "KvizSwitchFromArchive - KvizGoto failed - Please contact F2: %s", kvizPos);
                }
            }

            int archiveTSLen = Kviz_hArchiveTraversalStack.Get(i, 0);
            Kviz[context].Kviz_iTraversalStackLen = archiveTSLen;
            for (int j = 0; j < archiveTSLen; j++) {
                Kviz[context].Kviz_iTraversalStack[j] = Kviz_hArchiveTraversalStack.Get(i, j+1);
            }

            Kviz_hArchiveKv.Erase(i);
            Kviz_hArchiveTraversalStack.Erase(i);

            return true;
        }
    }

    return false;
}

stock int KvizGetFreeContext() {
    int best = -1;
    for (int context = 0; context < Kviz_iMaxContexts; context++) {
        if (Kviz[context].Kviz_hKv == null) {
            return context;
        }

        if (best == -1 || Kviz[context].Kviz_iLRU < Kviz[best].Kviz_iLRU) {
            best = context;
        }
    }

    KvizArchiveContext(best);
    KvizResetContext(best);
    return best;
}

stock void KvizArchiveContext(int context) {
    Kviz_hArchiveKv.Push(Kviz[context].Kviz_hKv);
    int stack[Kviz_iMaxTraversalStack+1];
    stack[0] = Kviz[context].Kviz_iTraversalStackLen;
    for (int i = 0; i < stack[0]; i++) {
        stack[i+1] = Kviz[context].Kviz_iTraversalStack[i];
    }
    Kviz_hArchiveTraversalStack.PushArray(stack);
    Kviz[context].Kviz_hKv = null;
}

stock bool KvizRemoveContext(KeyValues kv) {
    for (int i = 0; i < Kviz_iMaxContexts; i++) {
        if (Kviz[Kviz_iCurrentContext].Kviz_hKv == kv) {
            Kviz[Kviz_iCurrentContext].Kviz_hKv = null;
            return true;
        }

        if (Kviz_iCurrentContext == 0) {
            Kviz_iCurrentContext = Kviz_iMaxContexts - 1;
        }
        else {
            Kviz_iCurrentContext--;
        }
    }

    return false;
}

stock void KvizThrowError(KeyValues kv, const char[] text, any ...) {
    char buffer[256];
    VFormat(buffer, sizeof(buffer), text, 2);
    ThrowError("Kvizzle - %s", buffer);
}