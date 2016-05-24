// Copyright 1998-2016 Epic Games, Inc. All Rights Reserved.

using UnrealBuildTool;
using System;
using System.IO;

public class PlatformerGame : ModuleRules
{
	public PlatformerGame(TargetInfo Target)
	{
		PublicDependencyModuleNames.AddRange(
			new string[] {
				"Core",
				"CoreUObject",
				"Engine",
				"InputCore",
               	"GameMenuBuilder",
			}
		);

		PrivateDependencyModuleNames.AddRange(
			new string[] {
				"PlatformerGameLoadingScreen"
			}
		);

		PrivateDependencyModuleNames.AddRange(
			new string[] {
				"Slate",
				"SlateCore",
			}
		);

	  PrivateIncludePaths.AddRange(new string[] {
		  "PlatformerGame/Private/UI/Menu",
		});

		var moduleDir = Path.GetDirectoryName(RulesCompiler.GetModuleFilename(this.GetType().Name));
		PrivateIncludePaths.Add(Path.Combine(Environment.GetEnvironmentVariable("NIM_HOME"), "lib"));
		PublicIncludePaths.Add(Path.Combine(moduleDir, ".nimgen", "Public"));
		PrivateIncludePaths.Add(Path.Combine(moduleDir, ".nimgen", "Private"));
		UEBuildConfiguration.bForceEnableExceptions = true;
	}
}
