# compose-oneliner

wget -qO- <https://raw.githubusercontent.com/AnyVisionltd/compose-oneliner/development/compose-oneliner.sh> | bash -s -- -b \<BRANCH\> -k \<TOKEN\> [-p \<PRODUCT\>] [-g \<GIT\>] [--download-dashboard] [--dashboard-version] [--download-only]

* the default git is <https://github.com/AnyVisionltd>

To download compose-V2 use:

wget -qO- <https://raw.githubusercontent.com/AnyVisionltd/compose-oneliner/development/compose-oneliner.sh> | bash -s -- -b development -k <GCR_TOKEN> -g compose-v2 --nvidia-driver-version 440[--help]
