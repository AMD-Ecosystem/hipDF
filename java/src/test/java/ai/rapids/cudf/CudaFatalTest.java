/*
 * Copyright (c) 2022-2023, NVIDIA CORPORATION.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// MIT License
//
// Modifications Copyright (C) 2023-2025 Advanced Micro Devices, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// NOTE(HIP/AMD): This test is intended to fail:
// It is testing how the system handles CUDA-related fatal errors
// when working with column vectors in cuDF. It creates a ColumnVector,
// and later, it tries converting the vector to long integers (asLongs()),
// which could trigger CUDA operations.
// Class BadDeviceBuffer represents a defective device buffer;
// it causes CUDA fatal error by operating on a bad device buffer.
// In essence, it is similar to libcudf error_handling_test:
// (cudf-rocm/cpp/tests/error/error_handling_test.cu).
// On CUDA, an exception is raised which is handled later in the test.
// On HIP side, unlike CUDA, execution is not continued after the error on the device.

package ai.rapids.cudf;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Disabled;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

public class CudaFatalTest {

  @Test @Disabled
  public void testCudaFatalException() {
    try (ColumnVector cv = ColumnVector.fromInts(1, 2, 3, 4, 5)) {

      try (ColumnView badCv = ColumnView.fromDeviceBuffer(new BadDeviceBuffer(), 0, DType.INT8, 256);
           ColumnView ret = badCv.sub(badCv);
           HostColumnVector hcv = ret.copyToHost()) {
      } catch (CudaException ignored) {
      }

      // CUDA API invoked by libcudf failed because of previous unrecoverable fatal error
      assertThrows(CudaFatalException.class, () -> {
        try (ColumnVector cv2 = cv.asLongs()) {
        } catch (CudaFatalException ex) {
          assertEquals(CudaException.CudaError.cudaErrorIllegalAddress, ex.getCudaError());
          throw ex;
        }
      });
    }

    // CUDA API invoked by RMM failed because of previous unrecoverable fatal error
    assertThrows(CudaFatalException.class, () -> {
      try (ColumnVector cv = ColumnVector.fromBoxedInts(1, 2, 3, 4, 5)) {
      } catch (CudaFatalException ex) {
        assertEquals(CudaException.CudaError.cudaErrorIllegalAddress, ex.getCudaError());
        throw ex;
      }
    });
  }

  private static class BadDeviceBuffer extends BaseDeviceMemoryBuffer {
    public BadDeviceBuffer() {
      super(256L, 256L, (MemoryBufferCleaner) null);
    }

    @Override
    public MemoryBuffer slice(long offset, long len) {
      return null;
    }
  }

}
