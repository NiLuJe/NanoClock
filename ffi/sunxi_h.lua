local ffi = require("ffi")

ffi.cdef[[
enum eink_update_mode {
  EINK_INIT_MODE = 1,
  EINK_DU_MODE = 2,
  EINK_GC16_MODE = 4,
  EINK_GC4_MODE = 8,
  EINK_A2_MODE = 16,
  EINK_GL16_MODE = 32,
  EINK_GLR16_MODE = 64,
  EINK_GLD16_MODE = 128,
  EINK_GU16_MODE = 132,
  EINK_GCK16_MODE = 144,
  EINK_GLK16_MODE = 148,
  EINK_CLEAR_MODE = 136,
  EINK_GC4L_MODE = 140,
  EINK_GCC16_MODE = 160,
  EINK_AUTO_MODE = 32768,
  EINK_DITHERING_Y1 = 25165824,
  EINK_DITHERING_Y4 = 41943040,
  EINK_DITHERING_SIMPLE = 75497472,
  EINK_DITHERING_NTX_Y1 = 142606336,
  EINK_GAMMA_CORRECT = 2097152,
  EINK_MONOCHROME = 4194304,
  EINK_REGAL_MODE = 524288,
  EINK_NO_MERGE = 2147483648,
};
static const int EINK_RECT_MODE = 1024;
]]
