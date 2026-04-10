import ClipTidyCore
import Foundation

let status = runCLI(
    arguments: Array(CommandLine.arguments.dropFirst()),
    readStdin: { String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self) },
    stdout: { FileHandle.standardOutput.write(Data($0.utf8)) },
    stderr: { FileHandle.standardError.write(Data($0.utf8)) },
    pasteboard: SystemPasteboard()
)
exit(status)
