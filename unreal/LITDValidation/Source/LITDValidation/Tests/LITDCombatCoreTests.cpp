#if WITH_DEV_AUTOMATION_TESTS

#include "Misc/AutomationTest.h"
#include "Combat/LITDCombatActionData.h"
#include "Combat/LITDEquilibriumComponent.h"
#include "Combat/LITDGoreComponent.h"
#include "Combat/LITDFinisherComponent.h"
#include "Combat/LITDDefenseResolverComponent.h"
#include "Combat/LITDCombatStyleData.h"

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLITDAnimationIndependentTimingTest,
    "LITD.Combat.Core.AnimationIndependentTiming",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FLITDAnimationIndependentTimingTest::RunTest(const FString& Parameters)
{
    ULITDCombatActionData* Action = NewObject<ULITDCombatActionData>();
    Action->StartupSeconds = 0.10f;
    Action->ActiveSeconds = 0.20f;
    Action->RecoverySeconds = 0.30f;
    FLITDCombatWindow ComboWindow;
    ComboWindow.Name = FName("Cancel.Combo");
    ComboWindow.StartSeconds = 0.22f;
    ComboWindow.EndSeconds = 0.48f;
    Action->Windows.Add(ComboWindow);

    const bool BeforePresentationChange = Action->IsWindowOpen(FName("Cancel.Combo"), 0.30f);
    Action->PresentationPlayRate = 2.75f;
    const bool AfterPresentationChange = Action->IsWindowOpen(FName("Cancel.Combo"), 0.30f);

    TestTrue(TEXT("Gameplay cancel window is open at authoritative combat time"), BeforePresentationChange);
    TestEqual(TEXT("Changing animation play rate cannot change gameplay timing"), AfterPresentationChange, BeforePresentationChange);
    TestEqual(TEXT("Active phase is derived from gameplay data"), Action->GetPhaseAtTime(0.15f), ELITDCombatActionPhase::Active);
    return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLITDCombatStyleStanceTest,
    "LITD.Combat.Core.StyleStanceEntry",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FLITDCombatStyleStanceTest::RunTest(const FString& Parameters)
{
    ULITDCombatStyleData* Style = NewObject<ULITDCombatStyleData>();
    FLITDStyleEntryAction Entry;
    Entry.Stance = ELITDCombatStance::Left;
    Entry.Input = ELITDCombatInput::Heavy;
    Entry.ActionId = FName("Sabre.Left.Heavy.01");
    Style->EntryActions.Add(Entry);
    TestEqual(TEXT("Weapon/unarmed style resolves action from stance + input"), Style->ResolveEntryActionId(ELITDCombatStance::Left, ELITDCombatInput::Heavy), FName("Sabre.Left.Heavy.01"));
    return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLITDDefenseThreatRulesTest,
    "LITD.Combat.Core.DefenseThreatRules",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FLITDDefenseThreatRulesTest::RunTest(const FString& Parameters)
{
    ULITDDefenseResolverComponent* Defense = NewObject<ULITDDefenseResolverComponent>();
    TestEqual(TEXT("Normal attack can be blocked"), Defense->ResolveThreatFromWindows(ELITDAttackThreatType::Normal, true, false, false, false, false), ELITDDefenseOutcome::Block);
    TestEqual(TEXT("Grab ignores ordinary block"), Defense->ResolveThreatFromWindows(ELITDAttackThreatType::Grab, true, false, false, false, false), ELITDDefenseOutcome::Hit);
    TestEqual(TEXT("Grab can be dodged"), Defense->ResolveThreatFromWindows(ELITDAttackThreatType::Grab, false, false, true, false, false), ELITDDefenseOutcome::Dodge);
    TestEqual(TEXT("Thrust rewards perfect deflection"), Defense->ResolveThreatFromWindows(ELITDAttackThreatType::Thrust, false, true, false, false, false), ELITDDefenseOutcome::PerfectParry);
    TestEqual(TEXT("Perfect dodge has highest defensive priority"), Defense->ResolveThreatFromWindows(ELITDAttackThreatType::Heavy, false, false, true, true, false), ELITDDefenseOutcome::PerfectDodge);
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
    TestTrue(TEXT("Slash can complete a severable wound once trauma threshold is reached"), Gore->ApplyLocalizedDamage(ELITDBodyZone::ArmRight, 1.0f, ELITDDamageNature::Slash, FVector::ZeroVector, FVector::ForwardVector));
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
