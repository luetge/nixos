{ pkgs }:
{
  ms-toolsai--vscode-ai = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "vscode-ai";
      publisher = "ms-toolsai";
      version = "0.48.0";
      sha256 = "sha256-0rTVL4I4b92xfzqi5yGQw7QNruIodsnYiwrzI+pk8SM=";
    };

    meta = {
      description = "Visual Studio Code extension for Azure Machine Learning";
      homepage = "https://marketplace.visualstudio.com/items?itemName=ms-toolsai.vscode-ai";
    };
  };

  ms-toolsai--vscode-ai-remote = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "vscode-ai-remote";
      publisher = "ms-toolsai";
      version = "0.48.0";
      sha256 = "sha256-or0ktxNm/eNJTn5c8j4Gffy73h+7zRSNDeRdByhrVI8=";
    };

    meta = {
      description = "This extension is used by the Azure Machine Learning Extension";
      homepage = "https://marketplace.visualstudio.com/items?itemName=ms-toolsai.vscode-ai-remote";
    };
  };
}
