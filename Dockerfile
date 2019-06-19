FROM homeassistant/home-assistant

# OpenCV installation to support TensorFlow
RUN apt-get update \
  && apt-get install -y \
        cmake \
        git \
        wget \
        unzip \
        yasm \
        pkg-config \
        libswscale-dev \
        libtbb2 \
        libtbb-dev \
        libjpeg-dev \
        libpng-dev \
        libtiff-dev \
        libavformat-dev \
        libpq-dev \
        libv4l-dev \
        libhdf5-dev \
        libgstreamer-plugins-base1.0-dev

RUN echo 'deb http://ftp.de.debian.org/debian testing main' >> /etc/apt/sources.list \
  && echo 'APT::Default-Release "stable";' | tee -a /etc/apt/apt.conf.d/00local \
  && apt-get update && apt -y -t testing install gcc-7 g++-7 build-essential

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 100 --slave /usr/bin/g++ g++ /usr/bin/g++-7 \
  && update-alternatives --install /usr/bin/cpp cpp-bin /usr/bin/cpp-7 100 --slave /usr/bin/x86_64-linux-gnu-cpp x86_64-linux-gnu-cpp /usr/bin/cpp-7

RUN pip install numpy

# Intel MKL
WORKDIR /usr/src
RUN wget -q https://github.com/intel/mkl-dnn/archive/v0.19.tar.gz \
  && tar xzf v0.19.tar.gz
RUN cd mkl-dnn-0.19/scripts && ./prepare_mkl.sh && cd .. \
  && mkdir -p build && cd build && cmake .. \
  && make && make install && rm -rf /usr/src/mkl-dnn-0.19

# Needed to build tensorflow from source with MKL and native CPU
WORKDIR /usr/src
RUN wget -q https://github.com/bazelbuild/bazel/releases/download/0.19.2/bazel-0.19.2-installer-linux-x86_64.sh \
  && chmod +x bazel-0.19.2-installer-linux-x86_64.sh
RUN ./bazel-0.19.2-installer-linux-x86_64.sh --prefix=/opt/bazel \
  && ln -sf /opt/bazel/bin/bazel /usr/bin && rm -rf /usr/src/bazel-0.19.2-installer-linux-x86_64.sh

RUN git clone https://github.com/tensorflow/tensorflow.git --branch v1.13.1 --depth=1
RUN cd tensorflow && bazel build -c opt --config=mkl --copt=-march=native --copt=-mfpmath=both \
--jobs 1 --local_resources=3000,4,1 --genrule_strategy=standalone //tensorflow/tools/pip_package:build_pip_package

WORKDIR /usr/src/tensorflow
RUN ls -l && ./bazel-bin/tensorflow/tools/pip_package/build_pip_package /config/tensorflow_pkg \
  && pip install --upgrade --no-deps --force-reinstall /config/tensorflow_pkg/tensorflow-1.13.1-*.whl
RUN rm -rf /opt/bazel /usr/bin/bazel

WORKDIR /usr/src
ENV OPENCV_VERSION="4.0.1"
RUN wget https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.tar.gz \
  && tar xzvf ${OPENCV_VERSION}.tar.gz && rm -rf ${OPENCV_VERSION}.tar.gz

RUN wget https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip \
  && unzip ${OPENCV_VERSION}.zip
RUN mkdir /usr/src/opencv-${OPENCV_VERSION}/cmake_binary \
  && cd /usr/src/opencv-${OPENCV_VERSION}/cmake_binary \
  && cmake -DBUILD_TIFF=ON \
  -DBUILD_opencv_java=OFF \
  -DWITH_CUDA=OFF \
  -DWITH_OPENGL=OFF \
  -DWITH_OPENCL=ON \
  -DWITH_IPP=ON \
  -DWITH_TBB=OFF \
  -DWITH_EIGEN=ON \
  -DWITH_V4L=ON \
  -DWITH_QT=OFF \
  -DWITH_MKL=ON \
  -DMKL_USE_MULTITHREAD=ON \
  -DOPENCV_ENABLE_NONFREE=ON \
  -DENABLE_NEON=OFF \
  -DENABLE_VFPV3=OFF \
  -DOPENCV_EXTRA_MODULES_PATH=/opencv_contrib-${OPENCV_VERSION}/modules \
  -DBUILD_TESTS=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_PERF_TESTS=OFF \
  -DCMAKE_BUILD_TYPE=RELEASE \
  -DCMAKE_INSTALL_PREFIX=$(python3.7 -c "import sys; print(sys.prefix)") \
  -DPYTHON_EXECUTABLE=$(which python3.7) \
  -DPYTHON_INCLUDE_DIR=$(python3.7 -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
  -DPYTHON_PACKAGES_PATH=$(python3.7 -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
  .. \
  && make install

RUN ln -s /usr/local/python/cv2/python-3.7/cv2.cpython-37m-x86_64-linux-gnu.so \
/usr/local/lib/python3.7/site-packages/cv2.so

RUN rm -rf /usr/src/${OPENCV_VERSION}.zip /usr/src/opencv-${OPENCV_VERSION} \
  && rm -rf /var/lib/apt/lists/* /usr/src/*.zip /usr/src/*.gz

WORKDIR /usr/src/app
