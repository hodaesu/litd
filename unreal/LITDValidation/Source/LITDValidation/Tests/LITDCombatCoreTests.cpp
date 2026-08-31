#if WITH_DEV_AUTOMATION_TESTS

#include "Misc/AutomationTest.h"
#include "Combat/LITDCombatActionData.h"
#include "Combat/LITDEquilibriumComponent.h"
#include "Combat/LITDGoreComponent.h"
#include "Combat/LITDFinisherComponent.h"

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLITDAnimationIndependentTimingTest,
    "LITD.Combat.Core.AnimationIndependentTiming",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FLITDAnimationIndependentTimingTest::RunTest(const FString& Parameters)
{
    ULITDCombatActionData* Action = NewObject<ULITDCombatActionData>();
    Action->StartupSeconds = 0.10f;
    Action->ActiveSeconds = 0.20f;
    Action->RecoverySeconds = 0.30f;
    Action->Windows.Add({FName("Cancel.Combo"), 0.22f, 0.48f});

    const bool BeforePresentationChange = Action->IsWindowOpen(FName("Cancel.Combo"), 0.30f);
    Action->PresentationPlayRate = 2.75f;
    const bool AfterPresentationChange = Action->IsWindowOpen(FName("Cancel.Combo"), 0.30f);

    TestTrue(TEXT("Gameplay cancel window is open at authoritative combat time"), BeforePresentationChange);
    TestEqual(TEXT("Changing animation play rate cannot change gameplay timing"), AfterPresentationChange, BeforePresentationChange);
    TestEqual(TEXT("Active phase is derived from gameplay data"), Action->GetPhaseAtTime(0.15f), ELITDCombatActionPhase::Active);
    return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLITDEquilibriumBreakTest,
    "LITD.Combat.Core.EquilibriumBreak",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FLITDEquilibriumBreakTest::RunTest(const FString& Parameters)
{
    ULITDEquilibriumComponent* Component = NewObject<ULITDEquilibriumComponent>();
    Component->MaxEquilibrium = 100.0f;
    Component->ResetEquilibrium();
    Component->ApplyEquilibriumDamage(100.0f);
    TestTrue(TEXT("Equilibrium reaches broken state from gameplay damage"), Component->IsBroken());
    return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLITDDismembermentThresholdTest,
    "LITD.Combat.Core.DismembermentThreshold",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FLITDDismembermentThresholdTest::RunTest(const FString& Parameters)
{
    ULITDGoreComponent* Gore = NewObject<ULITDGoreComponent>();
    FLITDBodyPartState Arm;
    Arm.Zone = ELITDBodyZone::ArmRight;
    Arm.Integrity = 100.0f;
    Arm.SeverThreshold = 50.0f;
    Arm.bCanSever = true;
    Gore->BodyParts.Add(Arm);

    TestFalse(TEXT("Blunt trauma does not sever a limb"), Gore->ApplyLocalizedDamage(ELITDBodyZone::ArmRight, 55.0f, ELITDDamageNature::Blunt, FVector::ZeroVector, FVector::ZeroVector));
    TestTrue(TEXT("Slash trauma can sever once threshold is reached"), Gore->ApplyLocalizedDamage(ELITDBodyZone::ArmRight, 1.0f, ELITDDamageNature::Slash, FVector::ZeroVector, FVector::ForwardVector));
    TestTrue(TEXT("Logical body state records severing"), Gore->IsSevered(ELITDBodyZone::ArmRight));
    return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLITDFinisherEligibilityTest,
    "LITD.Combat.Core.FinisherEligibility",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FLITDFinisherEligibilityTest::RunTest(const FString& Parameters)
{
    ULITDFinisherComponent* Component = NewObject<ULITDFinisherComponent>();
    ULITDFinisherData* Finisher = NewObject<ULITDFinisherData>();
    Finisher->MaxTargetHealthRatio = 0.25f;
    Finisher->MaxDistance = 180.0f;
    Finisher->bRequiresBrokenEquilibrium = true;

    const TArray<FName> Tags;
    TestFalse(TEXT("Healthy target cannot be finished"), Component->IsEligible(Finisher, 0.70f, true, 100.0f, Tags));
    TestFalse(TEXT("Unbroken target cannot be finished"), Component->IsEligible(Finisher, 0.20f, false, 100.0f, Tags));
    TestTrue(TEXT("Low-health broken target in range can be finished"), Component->IsEligible(Finisher, 0.20f, true, 100.0f, Tags));
    return true;
}

#endif
