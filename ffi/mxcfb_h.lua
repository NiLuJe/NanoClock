local ffi = require("ffi")

ffi.cdef[[
static const int UPDATE_MODE_PARTIAL = 0;
static const int UPDATE_MODE_FULL = 1;
static const int NTX_WFM_MODE_INIT = 0;
static const int NTX_WFM_MODE_DU = 1;
static const int NTX_WFM_MODE_GC16 = 2;
static const int NTX_WFM_MODE_GC4 = 3;
static const int NTX_WFM_MODE_A2 = 4;
static const int NTX_WFM_MODE_GL16 = 5;
static const int NTX_WFM_MODE_GLR16 = 6;
static const int NTX_WFM_MODE_GLD16 = 7;
static const int NTX_WFM_MODE_TOTAL = 8;
static const int WAVEFORM_MODE_INIT = 0;
static const int WAVEFORM_MODE_DU = 1;
static const int WAVEFORM_MODE_GC16 = 2;
static const int WAVEFORM_MODE_GC4 = 3;
static const int WAVEFORM_MODE_A2 = 4;
static const int WAVEFORM_MODE_GL16 = 5;
static const int WAVEFORM_MODE_REAGL = 6;
static const int WAVEFORM_MODE_REAGLD = 7;
static const int WAVEFORM_MODE_AUTO = 257;
static const int WAVEFORM_MODE_GLR32 = 6;
static const int WAVEFORM_MODE_GLR16 = 6;
static const int WAVEFORM_MODE_GLD16 = 7;
static const int TEMP_USE_AMBIENT = 4096;
static const int EPDC_FLAG_ENABLE_INVERSION = 1;
static const int EPDC_FLAG_FORCE_MONOCHROME = 2;
static const int EPDC_FLAG_USE_CMAP = 4;
static const int EPDC_FLAG_USE_ALT_BUFFER = 256;
static const int EPDC_FLAG_USE_AAD = 4096;
static const int EPDC_FLAG_TEST_COLLISION = 512;
static const int EPDC_FLAG_GROUP_UPDATE = 1024;
static const int EPDC_FLAG_USE_DITHERING_Y1 = 8192;
static const int EPDC_FLAG_USE_DITHERING_Y4 = 16384;
static const int EPDC_FLAG_USE_REGAL = 32768;
static const int EPDC_FLAG_USE_DITHERING_NTX_D8 = 1048576;
enum mxcfb_dithering_mode {
  EPDC_FLAG_USE_DITHERING_PASSTHROUGH = 0,
  EPDC_FLAG_USE_DITHERING_FLOYD_STEINBERG = 1,
  EPDC_FLAG_USE_DITHERING_ATKINSON = 2,
  EPDC_FLAG_USE_DITHERING_ORDERED = 3,
  EPDC_FLAG_USE_DITHERING_QUANT_ONLY = 4,
  EPDC_FLAG_USE_DITHERING_MAX = 5,
};
]]
