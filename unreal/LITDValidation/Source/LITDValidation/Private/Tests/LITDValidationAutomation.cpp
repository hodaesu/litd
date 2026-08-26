#if WITH_DEV_AUTOMATION_TESTS

#include "Misc/AutomationTest.h"
#include "LITDValidationCharacter.h"
#include "LITDValidationEnemy.h"
#include "LITDValidationGameMode.h"
#include "LITDValidationHUD.h"
#include "LITDValidationRoom.h"
#include "LITDValidationStation.h"

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLITDValidationClassesTest, "LITD.ValidationRoom.ClassesLoad", EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FLITDValidationClassesTest::RunTest(const FString& Parameters)
{
    TestNotNull(TEXT("Game mode class"), ALITDValidationGameMode::StaticClass());
    TestNotNull(TEXT("Character class"), ALITDValidationCharacter::StaticClass());
    TestNotNull(TEXT("Room class"), ALITDValidationRoom::StaticClass());
    TestNotNull(TEXT("Station class"), ALITDValidationStation::StaticClass());
    TestNotNull(TEXT("Enemy class"), ALITDValidationEnemy::StaticClass());
    TestNotNull(TEXT("HUD class"), ALITDValidationHUD::StaticClass());
    return true;
}

#endif
