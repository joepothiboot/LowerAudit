#include "mlir/Conversion/TosaToLinalg/TosaToLinalg.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/Index/IR/IndexDialect.h"
#include "mlir/Dialect/Linalg/IR/Linalg.h"
#include "mlir/Dialect/Math/IR/Math.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/Dialect/Tensor/IR/Tensor.h"
#include "mlir/Dialect/Tosa/IR/TosaOps.h"
#include "mlir/Dialect/Tosa/Transforms/Passes.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/InitAllDialects.h"
#include "mlir/InitAllExtensions.h"
#include "mlir/Support/FileUtilities.h"
#include "mlir/Transforms/DialectConversion.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/JSON.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/raw_ostream.h"

#include <cstdlib>
#include <memory>
#include <optional>
#include <string>
#include <system_error>

using namespace mlir;

enum ExitCode : int
{
  ExitOk = 0,
  ExitModuleFailed = 1,
  ExitUsage = 2,
  ExitTodo = 3,
};

[[noreturn]] void todo(llvm::StringRef function)
{
  llvm::errs() << "TODO: " << function << "\n";
  std::exit(ExitTodo);
}

class JsonLineWriter
{
public:
  explicit JsonLineWriter(llvm::raw_ostream &os) : os(os) {}

  void write(llvm::json::Object line)
  {
    os << llvm::json::Value(std::move(line)) << '\n';
    os.flush();
  }

private:
  llvm::raw_ostream &os;
};

DialectRegistry makeRegistry()
{
  DialectRegistry registry;
  registerAllDialects(registry);
  registerAllExtensions(registry);
  return registry;
}

void loadPassDialects(MLIRContext &context)
{
  context.loadDialect<tosa::TosaDialect, arith::ArithDialect,
                      linalg::LinalgDialect, math::MathDialect,
                      index::IndexDialect, tensor::TensorDialect,
                      scf::SCFDialect>();
}

class EventListener : public RewriterBase::Listener
{
public:
  explicit EventListener(JsonLineWriter &events) : events(events) {}

  void notifyPatternBegin(const Pattern &pattern, Operation *op) override
  {
    todo("notifyPatternBegin");
  }

  void notifyPatternEnd(const Pattern &pattern, LogicalResult status) override
  {
    todo("notifyPatternEnd");
  }

  void
  notifyMatchFailure(Location loc,
                     function_ref<void(Diagnostic &)> reasonCallback) override
  {
    todo("notifyMatchFailure");
  }

private:
  [[maybe_unused]] JsonLineWriter &events;
};

void buildTarget(ConversionTarget &target) { todo("buildTarget"); }

void observeMatchFailures(RewritePatternSet &patterns,
                          RewriterBase::Listener &listener)
{
  todo("observeMatchFailures");
}

LogicalResult convertFunction(func::FuncOp func, EventListener &listener)
{
  todo("convertFunction");
}

ExitCode runConversion(std::unique_ptr<llvm::MemoryBuffer> input,
                       JsonLineWriter &events)
{
  todo("runConversion");
}

void dumpPatterns(JsonLineWriter &out)
{
  MLIRContext context(makeRegistry(), MLIRContext::Threading::DISABLED);
  loadPassDialects(context);
  TypeConverter converter;
  tosa::populateTosaTypeConversion(converter);
  RewritePatternSet patterns(&context);
  tosa::populateTosaToLinalgConversionPatterns(converter, &patterns);
  for (const std::unique_ptr<RewritePattern> &pattern :
       patterns.getNativePatterns())
  {
    std::optional<OperationName> root = pattern->getRootKind();
    out.write(llvm::json::Object{
        {"kind", "registered"},
        {"pattern", pattern->getDebugName()},
        {"root", root ? llvm::json::Value(root->getStringRef())
                      : llvm::json::Value(nullptr)}});
  }
}

struct Options
{
  bool dumpPatterns = false;
  std::string eventsPath;
  std::string inputPath;
};

std::optional<Options> parseArgs(llvm::ArrayRef<const char *> args)
{
  Options options;
  for (llvm::StringRef arg : args)
  {
    if (arg == "--dump-patterns")
      options.dumpPatterns = true;
    else if (arg.consume_front("--events="))
      options.eventsPath = arg.str();
    else if (arg.starts_with("-") || !options.inputPath.empty())
      return std::nullopt;
    else
      options.inputPath = arg.str();
  }
  bool noPaths = options.eventsPath.empty() && options.inputPath.empty();
  bool bothPaths = !options.eventsPath.empty() && !options.inputPath.empty();
  if (options.dumpPatterns ? noPaths : bothPaths)
    return options;
  return std::nullopt;
}

int main(int argc, char **argv)
{
  std::optional<Options> options =
      parseArgs(llvm::ArrayRef<const char *>(argv + 1, argc - 1));
  if (!options)
  {
    llvm::errs() << "usage: lower-audit-adapter --events=<events.jsonl> "
                    "<input.mlir>\n"
                    "       lower-audit-adapter --dump-patterns\n";
    return ExitUsage;
  }

  if (options->dumpPatterns)
  {
    JsonLineWriter out(llvm::outs());
    dumpPatterns(out);
    return ExitOk;
  }

  std::string error;
  std::unique_ptr<llvm::MemoryBuffer> input =
      openInputFile(options->inputPath, &error);

  if (!input)
  {
    llvm::errs() << error << "\n";
    return ExitUsage;
  }

  std::error_code code;
  llvm::raw_fd_ostream eventsFile(options->eventsPath, code,
                                  llvm::sys::fs::OF_None);
  if (code)
  {
    llvm::errs() << "cannot open events file '" << options->eventsPath
                 << "': " << code.message() << "\n";
    return ExitUsage;
  }

  JsonLineWriter events(eventsFile);
  return runConversion(std::move(input), events);
}
