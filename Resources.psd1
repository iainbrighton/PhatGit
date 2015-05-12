ConvertFrom-StringData @'
    UsingParameterSet = Using parameter set '{0}'.
    RedirectingOutputStreams = Redirecting output streams.
    StatedProcess = Started process '{0}'.
    ProcessNotExitedCleanly = Process 'git {0}' did not exit cleanly within '{1}' second(s). The process may be waiting for user input or hasn't finished in the allotted time?
    StoppingProcess = Stopping process '{0}'.
    DisablingProcessTimeoutWarning = Ignoring known Git command '{0}'. The process timeout will be disabled and may cause the ISE to hang.
    KnownGitCommandWarning = Known problematic Git command '{0}' encountered. This command will NOT be executed.
    KnownGitCommandWithParameterWarning = Known problematic Git command '{0} {1}' encountered. This command will NOT be executed.

    MissingCommitMessageWarning = Missing an inline commit message which will launch an external text editor. Specify -m "Commit message" instead.
    InteractiveCommitMessageWarning = Interactive commits will launch an external editor, hanging the console. Remove the --Interactive switch.
'@