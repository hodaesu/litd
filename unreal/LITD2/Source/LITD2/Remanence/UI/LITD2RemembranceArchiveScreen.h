#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "Remanence/LITD2RemembranceTypes.h"
#include "LITD2RemembranceArchiveScreen.generated.h"

class ULITD2RemembranceSubsystem;
class USoundBase;

USTRUCT()
struct FLITD2ArchiveVisualNode
{
    GENERATED_BODY()

    FName EntryId = NAME_None;
    FText Title;
    FText Description;
    FString Category;
    FString Reliability;
    ELITD2RemembranceDiscoveryState InitialState = ELITD2RemembranceDiscoveryState::Unknown;
    TArray<FName> RelatedEntryIds;
    TArray<FName> ContradictionEntryIds;
    TArray<FName> SourceIds;
    FVector2D NormalizedPosition = FVector2D(0.5, 0.5);
    bool bInitialVisible = false;
};

USTRUCT()
struct FLITD2ArchiveVisualReconstruction
{
    GENERATED_BODY()

    FName ReconstructionId = NAME_None;
    FText Title;
    TArray<FName> RequiredEntryIds;
    TArray<FLITD2KnowledgeRequirementGroup> AlternativeRequirementGroups;
    FName ResultEntryId = NAME_None;
    TArray<FLITD2GameplayUnlock> Unlocks;
};

/**
 * Native UMG screen for the LITD 2 Remanence Archives.
 *
 * It owns the first production presentation in C++: documentary constellation,
 * animated threads, living/irregular nodes, ash-light ambience, sliding dossier,
 * contradiction feedback and a full knowledge-reconstruction reveal. A generated
 * WBP child can later replace art assets without replacing this interaction or
 * persistence contract.
 */
UCLASS(BlueprintType, Blueprintable)
class LITD2_API ULITD2RemembranceArchiveScreen : public UUserWidget
{
    GENERATED_BODY()

public:
    UFUNCTION(BlueprintCallable, Category="LITD2|Remanence|Archive UI")
    bool ReloadArchive();

    UFUNCTION(BlueprintCallable, Category="LITD2|Remanence|Archive UI")
    bool TryReconstructAvailable();

    UFUNCTION(BlueprintPure, Category="LITD2|Remanence|Archive UI")
    FName GetSelectedEntryId() const { return SelectedEntryId; }

    UFUNCTION(BlueprintCallable, Category="LITD2|Remanence|Archive UI")
    void SelectEntry(FName EntryId);

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Remanence|Archive UI")
    FString SeedRelativePath = TEXT("Data/Remanence/sarei_seed.json");

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Remanence|Archive UI")
    FString LayoutRelativePath = TEXT("Data/Remanence/sarei_ui_layout.json");

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Remanence|Archive UI", meta=(ClampMin="0.2", ClampMax="1.0"))
    float GraphWidthRatio = 0.72f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Remanence|Archive UI", meta=(ClampMin="0.1", ClampMax="1.0"))
    float MinZoom = 0.45f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Remanence|Archive UI", meta=(ClampMin="1.0", ClampMax="5.0"))
    float MaxZoom = 2.25f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Remanence|Presentation", meta=(ClampMin="0.1", ClampMax="3.0"))
    float IntroDuration = 1.25f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Remanence|Presentation", meta=(ClampMin="0.1", ClampMax="3.0"))
    float ThreadRevealDuration = 1.45f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Remanence|Presentation", meta=(ClampMin="0.05", ClampMax="2.0"))
    float DossierTransitionDuration = 0.32f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Remanence|Presentation", meta=(ClampMin="0.5", ClampMax="5.0"))
    float KnowledgeRevealDuration = 2.35f;

    // Optional sound assets. Native presentation remains functional when none are assigned.
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Remanence|Audio")
    TObjectPtr<USoundBase> OpenSound;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Remanence|Audio")
    TObjectPtr<USoundBase> SelectionSound;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Remanence|Audio")
    TObjectPtr<USoundBase> ContradictionSound;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Remanence|Audio")
    TObjectPtr<USoundBase> ReconstructionSound;

protected:
    virtual TSharedRef<SWidget> RebuildWidget() override;
    virtual void NativeConstruct() override;
    virtual void NativeDestruct() override;
    virtual void NativeTick(const FGeometry& MyGeometry, float InDeltaTime) override;

    virtual int32 NativePaint(
        const FPaintArgs& Args,
        const FGeometry& AllottedGeometry,
        const FSlateRect& MyCullingRect,
        FSlateWindowElementList& OutDrawElements,
        int32 LayerId,
        const FWidgetStyle& InWidgetStyle,
        bool bParentEnabled) const override;

    virtual FReply NativeOnMouseButtonDown(const FGeometry& InGeometry, const FPointerEvent& InMouseEvent) override;
    virtual FReply NativeOnMouseButtonUp(const FGeometry& InGeometry, const FPointerEvent& InMouseEvent) override;
    virtual FReply NativeOnMouseMove(const FGeometry& InGeometry, const FPointerEvent& InMouseEvent) override;
    virtual FReply NativeOnMouseWheel(const FGeometry& InGeometry, const FPointerEvent& InMouseEvent) override;

private:
    UPROPERTY(Transient)
    TObjectPtr<ULITD2RemembranceSubsystem> RemembranceSubsystem;

    TArray<FLITD2ArchiveVisualNode> Nodes;
    TArray<FLITD2ArchiveVisualReconstruction> Reconstructions;
    TMap<FName, int32> NodeIndexById;

    FVector2D PanOffset = FVector2D::ZeroVector;
    float Zoom = 1.0f;
    FName SelectedEntryId = NAME_None;
    bool bDraggingGraph = false;
    FVector2D LastDragLocal = FVector2D::ZeroVector;

    float ArchiveAgeSeconds = 0.0f;
    float DossierTransitionSeconds = 0.0f;
    float ReconstructionPulseSeconds = 0.0f;
    float KnowledgeRevealSeconds = 0.0f;
    FName ReconstructionPulseEntryId = NAME_None;
    FText KnowledgeRevealTitle;
    FText KnowledgeRevealExplanation;
    TMap<FName, float> EntryRevealSeconds;

    bool LoadSeedJson(const FString& AbsolutePath);
    bool LoadLayoutJson(const FString& AbsolutePath);
    void BuildFallbackLayout();
    void InitializeAuthoringDefaults();

    bool IsNodeVisible(const FLITD2ArchiveVisualNode& Node) const;
    ELITD2RemembranceDiscoveryState GetNodeState(const FLITD2ArchiveVisualNode& Node) const;
    FVector2D GetNodeLocalPosition(const FLITD2ArchiveVisualNode& Node, const FVector2D& LocalSize) const;
    int32 HitTestNode(const FGeometry& Geometry, const FVector2D& LocalPosition) const;
    int32 FindAvailableReconstruction() const;
    FLinearColor CategoryColor(const FString& Category) const;
    FString DisplayState(ELITD2RemembranceDiscoveryState State) const;
    FString ReliabilityLabel(const FString& Reliability) const;
    void PlayUISound(USoundBase* Sound) const;
    void TriggerDossierTransition();

    UFUNCTION()
    void HandleEntryChanged(FName EntryId, ELITD2RemembranceDiscoveryState NewState);

    UFUNCTION()
    void HandleReconstructionCompleted(FName ReconstructionId);
};
