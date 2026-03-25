#!/usr/bin/env mise exec dotnet@10 -- dotnet run
#:package Humanizer@3.0.0-rc.30
// #:property TargetFramework=net8.0 // not work yet get below error
// https://aka.ms/dotnet-core-applaunch?framework=Microsoft.NETCore.App&framework_version=8.0.0&arch=arm64&rid=osx-arm64&os=osx.26
// bash-5.3$ ./test.cs 
// You must install or update .NET to run this application.
//
// App: /Users/tharutaipree/Library/Application Support/dotnet/runfile/test-073e667041a82b9d8cf47e554f4dfa69a79866089782780a3ceccb99f7fa04e7/bin/debu
// g/test
// Architecture: arm64
// Framework: 'Microsoft.NETCore.App', version '8.0.0' (arm64)
// .NET location: /Users/tharutaipree/.local/share/mise/installs/dotnet/10.0.201
//
// The following frameworks were found:
//   10.0.5 at [/Users/tharutaipree/.local/share/mise/installs/dotnet/10.0.201/shared/Microsoft.NETCore.App]
//
// Learn more:
// https://aka.ms/dotnet/app-launch-failed
//
// To install missing framework, download:
// https://aka.ms/dotnet-core-applaunch?framework=Microsoft.NETCore.App&framework_version=8.0.0&arch=arm64&rid=osx-arm64&os=osx.26
// bash-5.3$ 


// #!/usr/bin/env mise exec dotnet@8 -- dotnet run # does not work Couldn't find a project to run. Ensure a project exists in /Users/tharutaipree/AgodaGit/tools/trip-ai-tools/prompt, or pass the path to the project using --project.

using Humanizer;

var message = args.FirstOrDefault() ?? "Hello, World!";
Console.WriteLine("Hello from a shebang script!");
Console.WriteLine(message);
Console.WriteLine(TimeSpan.FromDays(10).Humanize());

// var message = args.FirstOrDefault() ?? "Hello, World!';
// Console.WriteLine("Hello from a shebang script!");
// Console.WriteLine(TimeSpan.FromDays(10).Humanize());
// #!/usr/bin/env dotnet run


// install mise install dotnet@10
// or run directly with cli run with mise exec dotnet@10 -- dotnet run /Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/tests/lang_coderun/test.cs
// dotnet8 does not work run with mise exec dotnet@8 -- dotnet run /Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/tests/lang_coderun/test.cs
