# GitHub Actions Workflow: Build kuzu XCFramework for macOS and iOS (device & simulator)

name: Build kuzu XCFramework

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-14

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install dependencies
        run: brew install cmake ninja python@3.10

      - name: Set up Python
        run: |
          echo "/opt/homebrew/opt/python@3.10/libexec/bin" >> $GITHUB_PATH
          python3 --version

      - name: Build macOS version
        run: |
          mkdir -p build_macos/lib
          make release NUM_THREADS=$(sysctl -n hw.physicalcpu)
          find build/release -name '*.a' -exec cp {} build_macos/lib/ \;

      - name: Package macOS version
        run: |
          cd build_macos/lib
          LIB_FILES=$(find . -name "*.a" -exec basename {} \; | sort | uniq)
          echo "Packaging: $LIB_FILES"
          libtool -static -o libkuzu_deps.a $LIB_FILES

      - name: Build iOS device version
        run: |
          export IOS_SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
          export IOS_DEPLOYMENT_TARGET=13.0
          mkdir -p build_ios
          cmake . \
            -G Ninja \
            -DCMAKE_SYSTEM_NAME=iOS \
            -DPLATFORM=OS \
            -DCMAKE_OSX_ARCHITECTURES=arm64 \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=${IOS_DEPLOYMENT_TARGET} \
            -DCMAKE_OSX_SYSROOT=${IOS_SDK_PATH} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_TOOLCHAIN_FILE=/Users/runner/work/kuzu/kuzu/toolchains/ios.toolchain.cmake \
            -DENABLE_WERROR=OFF \
            -DBUILD_SHELL=OFF \
            -DBUILD_TESTS=OFF \
            -DBUILD_BENCHMARK=OFF \
            -DBUILD_WASM=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY=build_ios/lib
          ninja -j$(sysctl -n hw.physicalcpu)

      - name: Package iOS device version
        run: |
          cd build_ios/lib
          ls -l
          LIB_FILES=$(find . -name "*.a" -exec basename {} \; | sort | uniq)
          echo "Packaging: $LIB_FILES"
          libtool -static -o libkuzu_deps.a $LIB_FILES

      - name: Build iOS simulator version
        run: |
          export IOS_SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
          export IOS_DEPLOYMENT_TARGET=13.0
          mkdir -p build_ios_simulator
          cmake . \
            -G Ninja \
            -DCMAKE_SYSTEM_NAME=iOS \
            -DPLATFORM=SIMULATORARM64 \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=${IOS_DEPLOYMENT_TARGET} \
            -DCMAKE_OSX_SYSROOT=${IOS_SDK_PATH} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_TOOLCHAIN_FILE=/Users/runner/work/kuzu/kuzu/toolchains/ios.toolchain.cmake \
            -DENABLE_WERROR=OFF \
            -DBUILD_SHELL=OFF \
            -DBUILD_TESTS=OFF \
            -DBUILD_BENCHMARK=OFF \
            -DBUILD_WASM=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY=build_ios_simulator/lib \
            -DCMAKE_VERBOSE_MAKEFILE=ON
          ninja -j$(sysctl -n hw.physicalcpu)

      - name: Package iOS simulator version
        run: |
          cd build_ios_simulator/lib
          LIB_FILES=$(find . -name "*.a" -exec basename {} \; | sort | uniq)
          echo "Packaging: $LIB_FILES"
          libtool -static -o libkuzu_deps.a $LIB_FILES

      - name: Create XCFramework
        run: |
          xcodebuild -create-xcframework \
            -library build_ios/lib/libkuzu_deps.a \
            -headers src/include/c_api \
            -library build_ios_simulator/lib/libkuzu_deps.a \
            -headers src/include/c_api \
            -library build_macos/lib/libkuzu_deps.a \
            -headers src/include/c_api \
            -output build/Kuzu.xcframework

      - name: Display XCFramework info
        run: |
          echo "✅ XCFramework 生成完毕:"
          lipo -info build_ios/lib/libkuzu_deps.a
          lipo -info build_ios_simulator/lib/libkuzu_deps.a
          lipo -info build_macos/lib/libkuzu_deps.a
