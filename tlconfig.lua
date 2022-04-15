return {
   build_dir = "tmp",
   source_dir = "src",
   include_dir = { "src" },

   warning_error = { "unused", "redeclaration" },

   gen_compat = "required",

   scripts = {
      build = {
         post = {
            "scripts/gen_rockspec.tl",
            "scripts/docgen.tl",
         },
      },
   },
}
