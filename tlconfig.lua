return {
   build_dir = "tmp",
   source_dir = "src",
   include_dir = { "scripts", "src", "types" },

   warning_error = { "unused", "redeclaration" },

   gen_compat = "required",

   scripts = {
      build = {
         pre = {
            "scripts/vendor_dtls.tl",
         },
         post = {
            "scripts/gen_rockspec.tl",
            "scripts/gen_documentation.tl",
            "scripts/lint.tl",
         },
      },
   },
}
