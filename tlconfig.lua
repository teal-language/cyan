return {
   build_dir = "tmp",
   source_dir = "src",
   include_dir = { "src" },

   warning_error = { "unused", "redeclaration" },

   gen_compat = "required",

   scripts = {
      ["scripts/gen_rockspec.tl"] = { "build:post" },
      ["scripts/docgen.tl"] = { "build:post" },
   },
}
