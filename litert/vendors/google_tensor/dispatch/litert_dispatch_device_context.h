// Copyright 2024 Google LLC.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef ODML_LITERT_LITERT_VENDORS_GOOGLE_TENSOR_DISPATCH_LITERT_DISPATCH_DEVICE_CONTEXT_H_
#define ODML_LITERT_LITERT_VENDORS_GOOGLE_TENSOR_DISPATCH_LITERT_DISPATCH_DEVICE_CONTEXT_H_

#include <cstddef>
#include <memory>

#include "absl/container/flat_hash_set.h"  // from @com_google_absl
#include "litert/c/litert_tensor_buffer.h"
#include "litert/cc/litert_expected.h"
#include "litert/vendors/c/litert_dispatch.h"
#include "litert/vendors/google_tensor/dispatch/sb_api.h"
#include "litert/vendors/google_tensor/dispatch/southbound.h"

class LiteRtDispatchDeviceContextT {
 public:
  using Ptr = std::unique_ptr<LiteRtDispatchDeviceContextT>;

  ~LiteRtDispatchDeviceContextT();

  static litert::Expected<Ptr> Create(
      const litert::google_tensor::Southbound& southbound);

  litert::Expected<LiteRtTensorBufferHandle> RegisterTensorBuffer(
      LiteRtTensorBuffer tensor_buffer);

  litert::Expected<void> UnregisterTensorBuffer(
      LiteRtTensorBufferHandle tensor_buffer_handle);

  litert::Expected<LiteRtDispatchGraph> CreateGraph();
  litert::Expected<void> DestroyGraph(LiteRtDispatchGraph graph);

  litert::Expected<LiteRtDispatchExecutableHandle> LoadExecutable(
      LiteRtDispatchExecutableType type,
      const LiteRtMemBuffer* bytecode_buffer);

  litert::Expected<void> UnloadExecutable(
      LiteRtDispatchExecutableHandle exec_handle);

  ThrContext* thr_context() { return thr_context_; }

  void add_graph(ThrGraph* graph) { thr_graphs_.insert(graph); }

 private:
  explicit LiteRtDispatchDeviceContextT(
      const litert::google_tensor::Southbound& southbound)
      : southbound_(southbound) {}

  const litert::google_tensor::Southbound& southbound_;
  ThrContext* thr_context_ = nullptr;
  absl::flat_hash_set<ThrGraph*> thr_graphs_;
};

#endif  // ODML_LITERT_LITERT_VENDORS_GOOGLE_TENSOR_DISPATCH_LITERT_DISPATCH_DEVICE_CONTEXT_H_
