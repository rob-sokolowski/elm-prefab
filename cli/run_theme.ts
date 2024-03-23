import * as Options from "./options";
import * as Generator from "./run_generator";
import * as ThemeWebComponents from "./templates/theme/engine";

const ThemeGenerator = require("./generators/theme");

export const generator = (options: any): Options.Generator => {
  return {
    name: "theme",
    generatorType: Options.GeneratorType.Standard,
    init: (runOptions: Options.RunOptions) => {
      ThemeWebComponents.copyTo(runOptions.internalSrc, true);
    },
    run: async (runOptions: Options.RunOptions) => {
      ThemeWebComponents.copyTo(runOptions.internalSrc, true);
      return await Generator.run(
        ThemeGenerator.Elm.Generate,
        runOptions.internalSrc,
        options
      );
    },
  };
};
