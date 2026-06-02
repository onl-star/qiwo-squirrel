/*
 * Local shim for rime/key_table.h
 * Provides the XK key symbols needed by MacOSKeyCodes.swift without X11 dependency.
 */

#ifndef RIME_KEY_TABLE_H_
#define RIME_KEY_TABLE_H_

// ---- Key symbols (from X11/keysym.h) ---------------------------------
#define XK_VoidSymbol    0xffffff

#define XK_BackSpace     0xff08
#define XK_Tab           0xff09
#define XK_Clear         0xff0b
#define XK_Return        0xff0d
#define XK_Pause         0xff13
#define XK_Escape        0xff1b
#define XK_Delete        0xffff
#define XK_Kana_Shift    0xff2e
#define XK_Eisu_Shift    0xff2f

#define XK_Home          0xff50
#define XK_Left          0xff51
#define XK_Up            0xff52
#define XK_Right         0xff53
#define XK_Down          0xff54
#define XK_Page_Up       0xff55
#define XK_Page_Down     0xff56
#define XK_End           0xff57

#define XK_Help          0xff6a

#define XK_KP_Multiply   0xffaa
#define XK_KP_Add        0xffab
#define XK_KP_Enter      0xff8d
#define XK_KP_Subtract   0xffad
#define XK_KP_Decimal    0xffae
#define XK_KP_Divide     0xffaf
#define XK_KP_Equal      0xffbd

#define XK_Shift_L       0xffe1
#define XK_Shift_R       0xffe2
#define XK_Control_L     0xffe3
#define XK_Control_R     0xffe4
#define XK_Caps_Lock     0xffe5
#define XK_Alt_L         0xffe9
#define XK_Alt_R         0xffea
#define XK_Super_L       0xffeb
#define XK_Super_R       0xffec
#define XK_Hyper_L       0xffed
#define XK_Meta_L        0xffe7
#define XK_Meta_R        0xffe8

#define XK_space         0x020
#define XK_exclam        0x021
#define XK_quotedbl      0x022
#define XK_numbersign    0x023
#define XK_percent       0x025
#define XK_ampersand     0x026
#define XK_apostrophe    0x027
#define XK_parenleft     0x028
#define XK_parenright    0x029
#define XK_asterisk      0x02a
#define XK_plus          0x02b
#define XK_comma         0x02c
#define XK_minus         0x02d
#define XK_period        0x02e
#define XK_slash         0x02f
#define XK_colon         0x03a
#define XK_semicolon     0x03b
#define XK_less          0x03c
#define XK_equal         0x03d
#define XK_greater       0x03e
#define XK_bracketleft   0x05b
#define XK_backslash     0x05c
#define XK_bracketright  0x05d
#define XK_underscore    0x05f
#define XK_grave         0x060

#define XK_a 0x061
#define XK_b 0x062
#define XK_c 0x063
#define XK_d 0x064
#define XK_e 0x065
#define XK_f 0x066
#define XK_g 0x067
#define XK_h 0x068
#define XK_i 0x069
#define XK_j 0x06a
#define XK_k 0x06b
#define XK_l 0x06c
#define XK_m 0x06d
#define XK_n 0x06e
#define XK_o 0x06f
#define XK_p 0x070
#define XK_q 0x071
#define XK_r 0x072
#define XK_s 0x073
#define XK_t 0x074
#define XK_u 0x075
#define XK_v 0x076
#define XK_w 0x077
#define XK_x 0x078
#define XK_y 0x079
#define XK_z 0x07a

#define XK_F 0x046
#define XK_section      0x0a7
#define XK_yen          0x0a5

// ---- Modifier masks --------------------------------------------------
enum RimeModifier {
  kShiftMask    = 1 << 0,
  kLockMask     = 1 << 1,
  kControlMask  = 1 << 2,
  kMod1Mask     = 1 << 3,
  kMod2Mask     = 1 << 4,
  kMod3Mask     = 1 << 5,
  kMod4Mask     = 1 << 6,
  kMod5Mask     = 1 << 7,
  kAltMask      = kMod1Mask,
  kSuperMask    = 1 << 26,
  kHyperMask    = 1 << 27,
  kMetaMask     = 1 << 28,
  kReleaseMask  = 1 << 30,
  kModifierMask = 0x5f001fff,
};

// ---- Key code lookup functions ---------------------------------------
int RimeGetModifierByName(const char *name);
const char *RimeGetModifierName(int modifier);
int RimeGetKeycodeByName(const char *name);
const char *RimeGetKeyName(int keycode);

#endif
