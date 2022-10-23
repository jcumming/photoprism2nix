{ lib, stdenv
, fetchurl
, symlinkJoin
}:

with lib;
let
  platform =  "x86_64";

  rpath = makeLibraryPath [stdenv.cc.libc stdenv.cc.cc.lib];

  patchLibs =
    if stdenv.isDarwin
    then ''
      install_name_tool -id $out/lib/libtensorflow.dylib $out/lib/libtensorflow.dylib
      install_name_tool -id $out/lib/libtensorflow_framework.dylib $out/lib/libtensorflow_framework.dylib
    ''
    else ''
      patchelf --set-rpath "${rpath}:$out/lib" $out/lib/libtensorflow.so
      patchelf --set-rpath "${rpath}" $out/lib/libtensorflow_framework.so
    '';

in stdenv.mkDerivation rec {
  pname = "libtensorflow";

  version = "1.15.0";
  src = fetchurl {
    url = "https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-cpu-linux-x86_64-${version}.tar.gz";
    sha256 = "sha256-3sv9WnCeztNSP1XM+iOTN6h+GrPgAO/aNhfbeeEDTe0=";
  };
 
  # Patch library to use our libc, libstdc++ and others
  buildCommand = ''
    mkdir -pv $out
    tar -C $out -xzf $src
    chmod -R +w $out
    ${patchLibs}

    # Write pkg-config file.
    mkdir $out/lib/pkgconfig
    cat > $out/lib/pkgconfig/tensorflow.pc << EOF
    Name: TensorFlow
    Version: ${version}
    Description: Library for computation using data flow graphs for scalable machine learning
    Requires:
    Libs: -L$out/lib -ltensorflow
    Cflags: -I$out/include/tensorflow
    EOF
  '';

  meta = {
    description = "C API for TensorFlow";
    homepage = "https://www.tensorflow.org/install/lang_c";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" "x86_64-darwin" ];
  };
}
