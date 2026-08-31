#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "Combat/LITDCombatTypes.h"
#include "LITDCombatRuntimeComponent.generated.h"

class ULITDCombatActionData;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FLITDActionEvent, ULITDCombatActionData*, Action);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FLITDWindowEvent, FName, WindowName, bool, bOpen);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FLITDPhaseEvent, ELITDCombatActionPhase, OldPhase, ELITDCombatActionPhase, NewPhase);

/** Gameplay-authoritative combat clock. Animation never advances or opens gameplay windows. */
UCLASS(ClassGroup=(LITD), meta=(BlueprintSpawnableComponent))
class LITDVALIDATION_API ULITDCombatRuntimeComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    ULITDCombatRuntimeComponent();

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Combat")
    TArray<TObjectPtr<ULITDCombatActionData>> ActionRegistry;

    UPROPERTY(BlueprintAssignable, Category="Combat")
    FLITDActionEvent OnActionStarted;

    UPROPERTY(BlueprintAssignable, Category="Combat")
    FLITDActionEvent OnActionEnded;

    UPROPERTY(BlueprintAssignable, Category="Combat")
    FLITDWindowEvent OnWindowChanged;

    UPROPERTY(BlueprintAssignable, Category="Combat")
    FLITDPhaseEvent OnPhaseChanged;

    UFUNCTION(BlueprintCallable, Category="Combat")
    bool RequestInput(ELITDCombatInput Input);

    UFUNCTION(BlueprintCallable, Category="Combat")
    bool StartActionById(FName ActionId);

    UFUNCTION(BlueprintCallable, Category="Combat")
    void CancelCurrentAction();

    UFUNCTION(BlueprintPure, Category="Combat")
    bool IsWindowOpen(FName WindowName) const;

    UFUNCTION(BlueprintPure, Category="Combat")
    float GetActionElapsedSeconds() const { return ActionElapsedSeconds; }

    UFUNCTION(BlueprintPure, Category="Combat")
    ELITDCombatActionPhase GetCurrentPhase() const { return CurrentPhase; }

    UFUNCTION(BlueprintPure, Category="Combat")
    ULITDCombatActionData* GetCurrentAction() const { return CurrentAction; }

protected:
    virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

private:
    UPROPERTY(Transient)
    TObjectPtr<ULITDCombatActionData> CurrentAction = nullptr;

    float ActionElapsedSeconds = 0.0f;
    ELITDCombatActionPhase CurrentPhase = ELITDCombatActionPhase::Idle;
    TSet<FName> OpenWindows;

    ELITDCombatInput BufferedInput = ELITDCombatInput::None;
    float BufferedInputRemaining = 0.0f;

    ULITDCombatActionData* FindActionById(FName ActionId) const;
    ULITDCombatActionData* FindDefaultAction(ELITDCombatInput Input) const;
    bool TryTransition(ELITDCombatInput Input);
    bool StartAction(ULITDCombatActionData* Action);
    void UpdatePhaseAndWindows();
    void FinishCurrentAction();
};
