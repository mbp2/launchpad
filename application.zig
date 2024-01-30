// A semver-compatible versioning scheme.
pub const ApiVersion = extern struct {
   // The major release version, i.e. 1.0.0...
   version_major: u16,
   // The minor release version, i.e. 1.1.0...
   version_minor: u16,
   // The patch release version, i.e. 1.1.1...
   version_patch: u16,
   // Whether this is a pre-release version.
   pre_release: bool,

   pub fn default() ApiVersion {
      return ApiVersion{
         .version_major = version_info.major,
         .version_minor = version_info.minor,
         .version_patch = version_info.patch,
         .pre_release = version_info.pre_release,
      };
   }
};

pub const BootloaderConfig = extern struct {
   api_version: ApiVersion,
   mappings: SystemMap,
};

pub const Framebuffer = extern struct {
   buffer_start: u64,
   buffer_info: FramebufferInfo,

   pub fn new(buffer_start: u64, buffer_info: FramebufferInfo) Framebuffer {
      return Framebuffer{
         .buffer_start = buffer_start,
         .buffer_info = buffer_info,
      };
   }

   pub fn createBuffer(self: *@This()) [*]u8 {
      return @as([*]u8, @ptrFromInt(&self.buffer_start));
   }
};

pub const FramebufferInfo = extern struct {
   // The length of the buffer in bytes.
   byte_length: usize,

   // The width of the buffer displayed in pixels.
   width: usize,

   // The height of the buffer displayed in pixels.
   height: usize,

   // The format of the pixel to be displayed.
   pixel_format: PixelFormat,

   // The number of bytes used per pixel displayed.
   bbp: usize,

   // Number of pixels between the start of a line and the start of the next.
   //
   // Some framebuffers use additional padding at the end of a line, so this
   // value might be larger than `horizontal_resolution`. It is
   // therefore recommended to use this field for calculating the start address of a line.
   stride: usize,
};

pub const PixelFormat = enum(u16) {
   rgb = 0,
   bgr = 1,
   un8 = 2,
   unknown = 3,
};

pub const BootInfo = extern struct {
   api_version: ApiVersion,
   memory_regions: [*]MemoryRegion,
   framebuffer: ?Framebuffer,
   physical_memory_offset: ?u64,
   recursive_index: ?u16,
   rdsp_address: ?u64,
   tls_address: ?TlsTemplate,
   ramdisk_address: ?u64,
   ramdisk_length: u64,
   kernel_address: u64,
   kernel_length: u64,
   kernel_image_offset: u64,

   pub fn new(memory_regions: [*]MemoryRegion) BootInfo {
      return BootInfo{
         .api_version = ApiVersion.default(),
         .memory_regions = memory_regions,
         .framebuffer = null,
         .physical_memory_offset = null,
         .recursive_index = null,
         .rdsp_address = null,
         .tls_template = null,
         .ramdisk_address = null,
         .ramdisk_length = 0,
         .kernel_address = 0,
         .kernel_length = 0,
         .kernel_image_offset = 0,
      };
   }
};

pub const MemoryRegion = extern struct {
   start: u64,
   end: u64,
   kind: MemoryRegionKind,

   pub fn empty() MemoryRegion {
      return MemoryRegion{
         .start = 0,
         .end = 0,
         .kind = MemoryRegionKind.bootloader,
      };
   }

   pub fn clone(self: *@This()) MemoryRegion {
      var new = MemoryRegion.empty();
      new.start = self.start;
      new.end = self.end;
      new.kind = self.kind;

      return new;
   }
};

pub const MemoryRegionKind = enum(u16) {
   usable = 0,
   bootloader = 1,
   unknown_uefi = 2,
   unknown_legacy = 3,
};

pub const Kernel = extern struct {
   address: usize,
};

pub const TlsTemplate = extern struct {
   start_address: u64,
   file_size: u64,
   mem_size: u64,
};

pub const SystemMap = extern struct {
   kernel_stack: Mapping,
   boot_info: Mapping,
   framebuffer: Mapping,
   physical_memory: ?Mapping,
   page_table_recursive: ?Mapping,
   aslr: bool,
   dynamic_range_start: ?Mapping,
   dynamic_range_end: ?Mapping,
   ramdisk_memory: Mapping,

   pub fn default() SystemMap {
      return SystemMap{
         .kernel_stack = Mapping.dynamic(),
         .boot_info = Mapping.dynamic(),
      };
   }
};

pub const Mapping = extern struct {
   address: u64,

   pub fn dynamic() Mapping {
      return Mapping{
         .address = 0,
      };
   }

   pub fn fixed(address: u64) Mapping {
      return Mapping{
         .address = address,
      };
   }

   pub fn serialise(self: *@This()) [9]u8 {
      if (self.address == 0) {
         return [9]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0 };
      } else |addr| {
         _ = addr; // TODO: fill in with `concat_1_8` function when generator is complete.
      }
   }
};

// IMPORTS //

const builtin = @import("builtin");
const std = @import("std");

// This is a module we generate within our build script and we add to the root module as an anonymous
// import so that we may use it here to check version compliance.
const version_info = @import("index.zig").version_info;
