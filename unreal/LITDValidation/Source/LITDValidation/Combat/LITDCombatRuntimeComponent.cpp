#include "Combat/LITDCombatRuntimeComponent.h"
#include "Combat/LITDCombatActionData.h"
#include "Combat/LITDCombatStyleData.h"

ULITDCombatRuntimeComponent::ULITDCombatRuntimeComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
}

void ULITDCombatRuntimeComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

    if (BufferedInput != ELITDCombatInput::None)
    {
        BufferedInputRemaining -= DeltaTime;
        if (CurrentAction && TryTransition(BufferedInput))
        {
            BufferedInput = ELITDCombatInput::None;
            BufferedInputRemaining = 0.0f;
            return;
        }
        if (BufferedInputRemaining <= 0.0f)
        {
            BufferedInput = ELITDCombatInput::None;
        }
    }

    if (!CurrentAction)
    {
        return;
    }

    ActionElapsedSeconds += DeltaTime;
    UpdatePhaseAndWindows();

    if (ActionElapsedSeconds >= CurrentAction->GetTotalDuration())
    {
        FinishCurrentAction();
        if (BufferedInput != ELITDCombatInput::None)
        {
            const ELITDCombatInput Pending = BufferedInput;
            BufferedInput = ELITDCombatInput::None;
            RequestInput(Pending);
        }
    }
}

bool ULITDCombatRuntimeComponent::RequestInput(const ELITDCombatInput Input)
{
    if (Input == ELITDCombatInput::None)
    {
        return false;
    }

    if (!CurrentAction)
    {
        return StartAction(FindDefaultAction(Input));
    }

    if (TryTransition(Input))
    {
        return true;
    }

    BufferedInput = Input;
    BufferedInputRemaining = CurrentAction->InputBufferSeconds;
    return false;
}

bool ULITDCombatRuntimeComponent::StartActionById(const FName ActionId)
{
    return StartAction(FindActionById(ActionId));
}

void ULITDCombatRuntimeComponent::CancelCurrentAction()
{
    FinishCurrentAction();
}

bool ULITDCombatRuntimeComponent::IsWindowOpen(const FName WindowName) const
{
    return OpenWindows.Contains(WindowName);
}

ULITDCombatActionData* ULITDCombatRuntimeComponent::FindActionById(const FName ActionId) const
{
    if (CombatStyle)
    {
        for (ULITDCombatActionData* Action : CombatStyle->Actions)
        {
            if (Action && Action->ActionId == ActionId)
            {
                return Action;
            }
        }
    }
    for (ULITDCombatActionData* Action : ActionRegistry)
    {
        if (Action && Action->ActionId == ActionId)
        {
            return Action;
        }
    }
    return nullptr;
}

ULITDCombatActionData* ULITDCombatRuntimeComponent::FindDefaultAction(const ELITDCombatInput Input) const
{
    if (CombatStyle)
    {
        const FName StyleAction = CombatStyle->ResolveEntryActionId(CurrentStance, Input);
        if (!StyleAction.IsNone())
        {
            return FindActionById(StyleAction);
        }
    }
    for (ULITDCombatActionData* Action : ActionRegistry)
    {
        if (Action && Action->Input == Input)
        {
            return Action;
        }
    }
    return nullptr;
}

bool ULITDCombatRuntimeComponent::TryTransition(const ELITDCombatInput Input)
{
    if (!CurrentAction)
    {
        return false;
    }
    const FLITDCombatTransition* Transition = CurrentAction->FindTransition(Input, ActionElapsedSeconds);
    return Transition && StartAction(FindActionById(Transition->NextActionId));
}

bool ULITDCombatRuntimeComponent::StartAction(ULITDCombatActionData* Action)
{
    if (!Action)
    {
        return false;
    }

    if (CurrentAction)
    {
        ULITDCombatActionData* Previous = CurrentAction;
        for (const FName OpenWindow : OpenWindows)
        {
            OnWindowChanged.Broadcast(OpenWindow, false);
        }
        OpenWindows.Reset();
        OnActionEnded.Broadcast(Previous);
    }

    CurrentAction = Action;
    CurrentStance = Action->ResultStance;
    ActionElapsedSeconds = 0.0f;
    const ELITDCombatActionPhase OldPhase = CurrentPhase;
    CurrentPhase = ELITDCombatActionPhase::Startup;
    BufferedInput = ELITDCombatInput::None;
    BufferedInputRemaining = 0.0f;
    if (OldPhase != CurrentPhase)
    {
        OnPhaseChanged.Broadcast(OldPhase, CurrentPhase);
    }
    OnActionStarted.Broadcast(CurrentAction);
    UpdatePhaseAndWindows();
    return true;
}

void ULITDCombatRuntimeComponent::UpdatePhaseAndWindows()
{
    if (!CurrentAction)
    {
        return;
    }

    const ELITDCombatActionPhase NewPhase = CurrentAction->GetPhaseAtTime(ActionElapsedSeconds);
    if (NewPhase != CurrentPhase)
    {
        const ELITDCombatActionPhase Old = CurrentPhase;
        CurrentPhase = NewPhase;
        OnPhaseChanged.Broadcast(Old, NewPhase);
    }

    TSet<FName> NewOpenWindows;
    for (const FLITDCombatWindow& Window : CurrentAction->Windows)
    {
        if (!Window.Name.IsNone() && Window.Contains(ActionElapsedSeconds))
        {
            NewOpenWindows.Add(Window.Name);
            if (!OpenWindows.Contains(Window.Name))
            {
                OnWindowChanged.Broadcast(Window.Name, true);
            }
        }
    }

    for (const FName OldWindow : OpenWindows)
    {
        if (!NewOpenWindows.Contains(OldWindow))
        {
            OnWindowChanged.Broadcast(OldWindow, false);
        }
    }
    OpenWindows = MoveTemp(NewOpenWindows);
}

void ULITDCombatRuntimeComponent::FinishCurrentAction()
{
    if (!CurrentAction)
    {
        return;
    }

    ULITDCombatActionData* Finished = CurrentAction;
    for (const FName OpenWindow : OpenWindows)
    {
        OnWindowChanged.Broadcast(OpenWindow, false);
    }
    OpenWindows.Reset();
    CurrentAction = nullptr;
    ActionElapsedSeconds = 0.0f;
    const ELITDCombatActionPhase OldPhase = CurrentPhase;
    CurrentPhase = ELITDCombatActionPhase::Idle;
    if (OldPhase != CurrentPhase)
    {
        OnPhaseChanged.Broadcast(OldPhase, CurrentPhase);
    }
    OnActionEnded.Broadcast(Finished);
}
