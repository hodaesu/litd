#include "Remanence/UI/LITD2RemembranceArchiveScreen.h"

#include "Brushes/SlateColorBrush.h"
#include "Dom/JsonObject.h"
#include "InputCoreTypes.h"
#include "Kismet/GameplayStatics.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Remanence/LITD2RemembranceDataAssets.h"
#include "Remanence/LITD2RemembranceSubsystem.h"
#include "Rendering/DrawElementTypes.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Sound/SoundBase.h"
#include "Styling/CoreStyle.h"
#include "Widgets/Layout/SBox.h"

namespace
{
    static const FSlateColorBrush SolidBrush(FLinearColor::White);
    constexpr int32 AshMoteCount = 42;

    ELITD2RemembranceDiscoveryState ParseDiscoveryState(const FString& Value)
    {
        if (Value == TEXT("Trace")) return ELITD2RemembranceDiscoveryState::Trace;
        if (Value == TEXT("Documented")) return ELITD2RemembranceDiscoveryState::Documented;
        if (Value == TEXT("Reconstructed")) return ELITD2RemembranceDiscoveryState::Reconstructed;
        if (Value == TEXT("Contested")) return ELITD2RemembranceDiscoveryState::Contested;
        return ELITD2RemembranceDiscoveryState::Unknown;
    }

    ELITD2UnlockType ParseUnlockType(const FString& Value)
    {
        if (Value == TEXT("GameplayFeature")) return ELITD2UnlockType::GameplayFeature;
        if (Value == TEXT("Battle")) return ELITD2UnlockType::Battle;
        if (Value == TEXT("Lore")) return ELITD2UnlockType::Lore;
        if (Value == TEXT("Equipment")) return ELITD2UnlockType::Equipment;
        if (Value == TEXT("SkillVariant")) return ELITD2UnlockType::SkillVariant;
        if (Value == TEXT("Oath")) return ELITD2UnlockType::Oath;
        if (Value == TEXT("Preparation")) return ELITD2UnlockType::Preparation;
        if (Value == TEXT("EnemyKnowledge")) return ELITD2UnlockType::EnemyKnowledge;
        if (Value == TEXT("LogisticsCapacity")) return ELITD2UnlockType::LogisticsCapacity;
        return ELITD2UnlockType::None;
    }

    void ReadNameArray(const TSharedPtr<FJsonObject>& Object, const TCHAR* Field, TArray<FName>& OutValues)
    {
        OutValues.Reset();
        if (!Object.IsValid() || !Object->HasField(Field))
        {
            return;
        }

        for (const TSharedPtr<FJsonValue>& Value : Object->GetArrayField(Field))
        {
            FString Text;
            if (Value.IsValid() && Value->TryGetString(Text))
            {
                OutValues.Add(FName(*Text));
            }
        }
    }

    TArray<FString> WrapWords(const FString& Input, int32 MaxCharacters)
    {
        TArray<FString> Words;
        Input.ParseIntoArrayWS(Words);

        TArray<FString> Lines;
        FString Current;
        for (const FString& Word : Words)
        {
            const FString Candidate = Current.IsEmpty() ? Word : Current + TEXT(" ") + Word;
            if (Candidate.Len() > MaxCharacters && !Current.IsEmpty())
            {
                Lines.Add(Current);
                Current = Word;
            }
            else
            {
                Current = Candidate;
            }
        }
        if (!Current.IsEmpty())
        {
            Lines.Add(Current);
        }
        return Lines;
    }

    FPaintGeometry PaintGeometryAt(const FGeometry& Geometry, const FVector2D& Position, const FVector2D& Size)
    {
        return Geometry.ToPaintGeometry(Size, FSlateLayoutTransform(Position));
    }

    void DrawSolidBox(
        FSlateWindowElementList& OutDrawElements,
        int32 Layer,
        const FGeometry& Geometry,
        const FVector2D& Position,
        const FVector2D& Size,
        const FLinearColor& Color)
    {
        FSlateDrawElement::MakeBox(
            OutDrawElements,
            Layer,
            PaintGeometryAt(Geometry, Position, Size),
            &SolidBrush,
            ESlateDrawEffect::None,
            Color);
    }

    void DrawTextLine(
        FSlateWindowElementList& OutDrawElements,
        int32 Layer,
        const FGeometry& Geometry,
        const FVector2D& Position,
        const FString& Text,
        int32 FontSize,
        const FLinearColor& Color,
        bool bBold = false)
    {
        const FSlateFontInfo Font = FCoreStyle::GetDefaultFontStyle(bBold ? TEXT("Bold") : TEXT("Regular"), FontSize);
        FSlateDrawElement::MakeText(
            OutDrawElements,
            Layer,
            PaintGeometryAt(Geometry, Position, FVector2D(1.0, 1.0)),
            Text,
            Font,
            ESlateDrawEffect::None,
            Color);
    }

    void DrawLine(
        FSlateWindowElementList& OutDrawElements,
        int32 Layer,
        const FGeometry& Geometry,
        const FVector2D& Start,
        const FVector2D& End,
        const FLinearColor& Color,
        float Thickness)
    {
        TArray<FVector2f> Points;
        Points.Add(FVector2f(Start));
        Points.Add(FVector2f(End));
        FSlateDrawElement::MakeLines(
            OutDrawElements,
            Layer,
            Geometry.ToPaintGeometry(),
            Points,
            ESlateDrawEffect::None,
            Color,
            true,
            Thickness);
    }

    void DrawThread(
        FSlateWindowElementList& OutDrawElements,
        int32 Layer,
        const FGeometry& Geometry,
        const FVector2D& Start,
        const FVector2D& End,
        float Reveal,
        float Phase,
        const FLinearColor& Color,
        float Thickness)
    {
        if (Reveal <= KINDA_SMALL_NUMBER)
        {
            return;
        }

        const FVector2D RevealedEnd = FMath::Lerp(Start, End, FMath::Clamp(Reveal, 0.0f, 1.0f));
        FVector2D Direction = RevealedEnd - Start;
        if (!Direction.Normalize())
        {
            return;
        }
        const FVector2D Perpendicular(-Direction.Y, Direction.X);
        const FVector2D Mid = FMath::Lerp(Start, RevealedEnd, 0.52f) + Perpendicular * FMath::Sin(Phase) * 2.8f;

        TArray<FVector2f> Points;
        Points.Add(FVector2f(Start));
        Points.Add(FVector2f(Mid));
        Points.Add(FVector2f(RevealedEnd));

        FSlateDrawElement::MakeLines(
            OutDrawElements,
            Layer,
            Geometry.ToPaintGeometry(),
            Points,
            ESlateDrawEffect::None,
            Color.CopyWithNewOpacity(Color.A * 0.18f),
            true,
            Thickness + 3.6f);

        FSlateDrawElement::MakeLines(
            OutDrawElements,
            Layer + 1,
            Geometry.ToPaintGeometry(),
            Points,
            ESlateDrawEffect::None,
            Color,
            true,
            Thickness);
    }

    void DrawDashedLine(
        FSlateWindowElementList& OutDrawElements,
        int32 Layer,
        const FGeometry& Geometry,
        const FVector2D& Start,
        const FVector2D& End,
        const FLinearColor& Color,
        float Thickness,
        float Reveal)
    {
        constexpr int32 SegmentCount = 18;
        const float ClampedReveal = FMath::Clamp(Reveal, 0.0f, 1.0f);
        for (int32 Segment = 0; Segment < SegmentCount; Segment += 2)
        {
            const float A = static_cast<float>(Segment) / SegmentCount;
            if (A >= ClampedReveal)
            {
                break;
            }
            const float B = FMath::Min(static_cast<float>(Segment + 1) / SegmentCount, ClampedReveal);
            DrawLine(
                OutDrawElements,
                Layer,
                Geometry,
                FMath::Lerp(Start, End, A),
                FMath::Lerp(Start, End, B),
                Color.CopyWithNewOpacity(Color.A * 0.18f),
                Thickness + 3.0f);
            DrawLine(
                OutDrawElements,
                Layer + 1,
                Geometry,
                FMath::Lerp(Start, End, A),
                FMath::Lerp(Start, End, B),
                Color,
                Thickness);
        }
    }

    float Hash01(int32 Seed)
    {
        return FMath::Frac(FMath::Abs(FMath::Sin(static_cast<float>(Seed) * 12.9898f) * 43758.5453f));
    }

    float Smooth01(float Value)
    {
        const float T = FMath::Clamp(Value, 0.0f, 1.0f);
        return T * T * (3.0f - 2.0f * T);
    }
}

TSharedRef<SWidget> ULITD2RemembranceArchiveScreen::RebuildWidget()
{
    return SNew(SBox);
}

void ULITD2RemembranceArchiveScreen::NativeConstruct()
{
    Super::NativeConstruct();

    ArchiveAgeSeconds = 0.0f;
    DossierTransitionSeconds = DossierTransitionDuration;
    ReconstructionPulseSeconds = 0.0f;
    KnowledgeRevealSeconds = 0.0f;
    EntryRevealSeconds.Reset();

    if (UGameInstance* GameInstance = GetGameInstance())
    {
        RemembranceSubsystem = GameInstance->GetSubsystem<ULITD2RemembranceSubsystem>();
    }

    if (RemembranceSubsystem)
    {
        RemembranceSubsystem->OnEntryChanged.AddUniqueDynamic(this, &ULITD2RemembranceArchiveScreen::HandleEntryChanged);
        RemembranceSubsystem->OnReconstructionCompleted.AddUniqueDynamic(this, &ULITD2RemembranceArchiveScreen::HandleReconstructionCompleted);
    }

    ReloadArchive();
    PlayUISound(OpenSound);
}

void ULITD2RemembranceArchiveScreen::NativeDestruct()
{
    if (RemembranceSubsystem)
    {
        RemembranceSubsystem->OnEntryChanged.RemoveDynamic(this, &ULITD2RemembranceArchiveScreen::HandleEntryChanged);
        RemembranceSubsystem->OnReconstructionCompleted.RemoveDynamic(this, &ULITD2RemembranceArchiveScreen::HandleReconstructionCompleted);
    }

    Super::NativeDestruct();
}

bool ULITD2RemembranceArchiveScreen::ReloadArchive()
{
    Nodes.Reset();
    Reconstructions.Reset();
    NodeIndexById.Reset();

    const FString SeedPath = FPaths::ConvertRelativePathToFull(FPaths::Combine(FPaths::ProjectDir(), SeedRelativePath));
    if (!LoadSeedJson(SeedPath))
    {
        return false;
    }

    const FString LayoutPath = FPaths::ConvertRelativePathToFull(FPaths::Combine(FPaths::ProjectDir(), LayoutRelativePath));
    if (!LoadLayoutJson(LayoutPath))
    {
        BuildFallbackLayout();
    }

    InitializeAuthoringDefaults();

    if (SelectedEntryId.IsNone() || !NodeIndexById.Contains(SelectedEntryId))
    {
        for (const FLITD2ArchiveVisualNode& Node : Nodes)
        {
            if (IsNodeVisible(Node))
            {
                SelectedEntryId = Node.EntryId;
                break;
            }
        }
    }

    InvalidateLayoutAndVolatility();
    return true;
}

bool ULITD2RemembranceArchiveScreen::LoadSeedJson(const FString& AbsolutePath)
{
    FString JsonText;
    if (!FFileHelper::LoadFileToString(JsonText, *AbsolutePath))
    {
        UE_LOG(LogTemp, Error, TEXT("LITD2 Remanence UI: impossible de lire %s"), *AbsolutePath);
        return false;
    }

    TSharedPtr<FJsonObject> Root;
    const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonText);
    if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid())
    {
        UE_LOG(LogTemp, Error, TEXT("LITD2 Remanence UI: JSON invalide %s"), *AbsolutePath);
        return false;
    }

    TSet<FName> InitiallyVisible;
    if (Root->HasField(TEXT("initial_archive")))
    {
        const TSharedPtr<FJsonObject> InitialArchive = Root->GetObjectField(TEXT("initial_archive"));
        if (InitialArchive.IsValid() && InitialArchive->HasField(TEXT("visible_entry_ids")))
        {
            for (const TSharedPtr<FJsonValue>& Value : InitialArchive->GetArrayField(TEXT("visible_entry_ids")))
            {
                FString Id;
                if (Value.IsValid() && Value->TryGetString(Id))
                {
                    InitiallyVisible.Add(FName(*Id));
                }
            }
        }
    }

    for (const TSharedPtr<FJsonValue>& Value : Root->GetArrayField(TEXT("entries")))
    {
        const TSharedPtr<FJsonObject> Object = Value.IsValid() ? Value->AsObject() : nullptr;
        if (!Object.IsValid())
        {
            continue;
        }

        FLITD2ArchiveVisualNode Node;
        Node.EntryId = FName(*Object->GetStringField(TEXT("entry_id")));
        Node.Title = FText::FromString(Object->GetStringField(TEXT("title")));
        Node.Description = FText::FromString(Object->GetStringField(TEXT("description")));
        Node.Category = Object->GetStringField(TEXT("category"));
        Node.Reliability = Object->GetStringField(TEXT("reliability"));
        Node.InitialState = ParseDiscoveryState(Object->GetStringField(TEXT("initial_state")));
        Node.bInitialVisible = InitiallyVisible.Contains(Node.EntryId);
        ReadNameArray(Object, TEXT("related_entry_ids"), Node.RelatedEntryIds);
        ReadNameArray(Object, TEXT("contradiction_entry_ids"), Node.ContradictionEntryIds);
        ReadNameArray(Object, TEXT("source_ids"), Node.SourceIds);

        NodeIndexById.Add(Node.EntryId, Nodes.Num());
        Nodes.Add(MoveTemp(Node));
    }

    if (Root->HasField(TEXT("reconstructions")))
    {
        for (const TSharedPtr<FJsonValue>& Value : Root->GetArrayField(TEXT("reconstructions")))
        {
            const TSharedPtr<FJsonObject> Object = Value.IsValid() ? Value->AsObject() : nullptr;
            if (!Object.IsValid())
            {
                continue;
            }

            FLITD2ArchiveVisualReconstruction Reconstruction;
            Reconstruction.ReconstructionId = FName(*Object->GetStringField(TEXT("reconstruction_id")));
            Reconstruction.Title = FText::FromString(Object->GetStringField(TEXT("title")));
            Reconstruction.ResultEntryId = FName(*Object->GetStringField(TEXT("result_entry_id")));
            ReadNameArray(Object, TEXT("required_entry_ids"), Reconstruction.RequiredEntryIds);

            if (Object->HasField(TEXT("alternative_requirement_groups")))
            {
                for (const TSharedPtr<FJsonValue>& GroupValue : Object->GetArrayField(TEXT("alternative_requirement_groups")))
                {
                    const TSharedPtr<FJsonObject> GroupObject = GroupValue.IsValid() ? GroupValue->AsObject() : nullptr;
                    if (!GroupObject.IsValid())
                    {
                        continue;
                    }

                    FLITD2KnowledgeRequirementGroup Group;
                    Group.MinimumMatches = GroupObject->GetIntegerField(TEXT("minimum_matches"));
                    ReadNameArray(GroupObject, TEXT("any_of_entry_ids"), Group.AnyOfEntryIds);
                    ReadNameArray(GroupObject, TEXT("any_of_source_ids"), Group.AnyOfSourceIds);
                    Reconstruction.AlternativeRequirementGroups.Add(MoveTemp(Group));
                }
            }

            if (Object->HasField(TEXT("unlocks")))
            {
                for (const TSharedPtr<FJsonValue>& UnlockValue : Object->GetArrayField(TEXT("unlocks")))
                {
                    const TSharedPtr<FJsonObject> UnlockObject = UnlockValue.IsValid() ? UnlockValue->AsObject() : nullptr;
                    if (!UnlockObject.IsValid())
                    {
                        continue;
                    }

                    FLITD2GameplayUnlock Unlock;
                    Unlock.UnlockId = FName(*UnlockObject->GetStringField(TEXT("unlock_id")));
                    Unlock.Type = ParseUnlockType(UnlockObject->GetStringField(TEXT("type")));
                    Unlock.IntegerValue = UnlockObject->GetIntegerField(TEXT("integer_value"));
                    Unlock.Explanation = FText::FromString(UnlockObject->GetStringField(TEXT("explanation")));
                    Reconstruction.Unlocks.Add(MoveTemp(Unlock));
                }
            }

            Reconstructions.Add(MoveTemp(Reconstruction));
        }
    }

    return Nodes.Num() > 0;
}

bool ULITD2RemembranceArchiveScreen::LoadLayoutJson(const FString& AbsolutePath)
{
    FString JsonText;
    if (!FFileHelper::LoadFileToString(JsonText, *AbsolutePath))
    {
        return false;
    }

    TSharedPtr<FJsonObject> Root;
    const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonText);
    if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid() || !Root->HasField(TEXT("nodes")))
    {
        return false;
    }

    TSet<FName> LaidOutIds;
    for (const TSharedPtr<FJsonValue>& Value : Root->GetArrayField(TEXT("nodes")))
    {
        const TSharedPtr<FJsonObject> Object = Value.IsValid() ? Value->AsObject() : nullptr;
        if (!Object.IsValid())
        {
            continue;
        }

        const FName EntryId(*Object->GetStringField(TEXT("entry_id")));
        if (const int32* Index = NodeIndexById.Find(EntryId))
        {
            Nodes[*Index].NormalizedPosition = FVector2D(
                FMath::Clamp(Object->GetNumberField(TEXT("x")), 0.04, 0.96),
                FMath::Clamp(Object->GetNumberField(TEXT("y")), 0.06, 0.94));
            LaidOutIds.Add(EntryId);
        }
    }

    return LaidOutIds.Num() == Nodes.Num();
}

void ULITD2RemembranceArchiveScreen::BuildFallbackLayout()
{
    const int32 Count = FMath::Max(1, Nodes.Num());
    for (int32 Index = 0; Index < Nodes.Num(); ++Index)
    {
        const double Angle = (2.0 * PI * Index / Count) - (PI * 0.5);
        const double Radius = 0.28 + (Index % 3) * 0.045;
        Nodes[Index].NormalizedPosition = FVector2D(
            0.5 + FMath::Cos(Angle) * Radius,
            0.5 + FMath::Sin(Angle) * Radius);
    }
}

void ULITD2RemembranceArchiveScreen::InitializeAuthoringDefaults()
{
    if (!RemembranceSubsystem)
    {
        return;
    }

    for (const FLITD2ArchiveVisualNode& Node : Nodes)
    {
        if (Node.bInitialVisible && Node.InitialState != ELITD2RemembranceDiscoveryState::Unknown &&
            RemembranceSubsystem->GetEntryState(Node.EntryId) == ELITD2RemembranceDiscoveryState::Unknown)
        {
            RemembranceSubsystem->SetEntryState(Node.EntryId, Node.InitialState);
        }
    }
}

ELITD2RemembranceDiscoveryState ULITD2RemembranceArchiveScreen::GetNodeState(const FLITD2ArchiveVisualNode& Node) const
{
    if (RemembranceSubsystem)
    {
        const ELITD2RemembranceDiscoveryState RuntimeState = RemembranceSubsystem->GetEntryState(Node.EntryId);
        if (RuntimeState != ELITD2RemembranceDiscoveryState::Unknown)
        {
            return RuntimeState;
        }
    }
    return Node.InitialState;
}

bool ULITD2RemembranceArchiveScreen::IsNodeVisible(const FLITD2ArchiveVisualNode& Node) const
{
    return Node.bInitialVisible || GetNodeState(Node) != ELITD2RemembranceDiscoveryState::Unknown;
}

FVector2D ULITD2RemembranceArchiveScreen::GetNodeLocalPosition(
    const FLITD2ArchiveVisualNode& Node,
    const FVector2D& LocalSize) const
{
    const double GraphWidth = LocalSize.X * GraphWidthRatio;
    const FVector2D GraphSize(GraphWidth, LocalSize.Y);
    const FVector2D Center = GraphSize * 0.5;
    const FVector2D Base(Node.NormalizedPosition.X * GraphSize.X, Node.NormalizedPosition.Y * GraphSize.Y);
    return Center + (Base - Center) * Zoom + PanOffset;
}

int32 ULITD2RemembranceArchiveScreen::HitTestNode(const FGeometry& Geometry, const FVector2D& LocalPosition) const
{
    const FVector2D LocalSize = Geometry.GetLocalSize();
    const FVector2D HalfSize(82.0, 34.0);
    for (int32 Index = Nodes.Num() - 1; Index >= 0; --Index)
    {
        const FLITD2ArchiveVisualNode& Node = Nodes[Index];
        if (!IsNodeVisible(Node))
        {
            continue;
        }

        const FVector2D Center = GetNodeLocalPosition(Node, LocalSize);
        if (FMath::Abs(LocalPosition.X - Center.X) <= HalfSize.X &&
            FMath::Abs(LocalPosition.Y - Center.Y) <= HalfSize.Y)
        {
            return Index;
        }
    }
    return INDEX_NONE;
}

void ULITD2RemembranceArchiveScreen::PlayUISound(USoundBase* Sound) const
{
    if (Sound)
    {
        UGameplayStatics::PlaySound2D(this, Sound);
    }
}

void ULITD2RemembranceArchiveScreen::TriggerDossierTransition()
{
    DossierTransitionSeconds = DossierTransitionDuration;
}

void ULITD2RemembranceArchiveScreen::SelectEntry(FName EntryId)
{
    const int32* Index = NodeIndexById.Find(EntryId);
    if (!Index || SelectedEntryId == EntryId)
    {
        return;
    }

    SelectedEntryId = EntryId;
    TriggerDossierTransition();
    PlayUISound(SelectionSound);

    if (Nodes[*Index].ContradictionEntryIds.Num() > 0)
    {
        PlayUISound(ContradictionSound);
    }

    InvalidateLayoutAndVolatility();
}

int32 ULITD2RemembranceArchiveScreen::FindAvailableReconstruction() const
{
    if (!RemembranceSubsystem)
    {
        return INDEX_NONE;
    }

    for (int32 Index = 0; Index < Reconstructions.Num(); ++Index)
    {
        const FLITD2ArchiveVisualReconstruction& Reconstruction = Reconstructions[Index];
        if (RemembranceSubsystem->IsReconstructionCompleted(Reconstruction.ReconstructionId))
        {
            continue;
        }

        bool bReady = true;
        for (const FName EntryId : Reconstruction.RequiredEntryIds)
        {
            if (RemembranceSubsystem->GetEntryState(EntryId) == ELITD2RemembranceDiscoveryState::Unknown)
            {
                bReady = false;
                break;
            }
        }
        if (!bReady)
        {
            continue;
        }

        for (const FLITD2KnowledgeRequirementGroup& Group : Reconstruction.AlternativeRequirementGroups)
        {
            int32 Matches = 0;
            for (const FName EntryId : Group.AnyOfEntryIds)
            {
                Matches += RemembranceSubsystem->GetEntryState(EntryId) != ELITD2RemembranceDiscoveryState::Unknown ? 1 : 0;
            }
            for (const FName SourceId : Group.AnyOfSourceIds)
            {
                Matches += RemembranceSubsystem->HasDiscoveredSource(SourceId) ? 1 : 0;
            }
            if (Matches < FMath::Max(1, Group.MinimumMatches))
            {
                bReady = false;
                break;
            }
        }

        if (bReady)
        {
            return Index;
        }
    }

    return INDEX_NONE;
}

bool ULITD2RemembranceArchiveScreen::TryReconstructAvailable()
{
    const int32 Index = FindAvailableReconstruction();
    if (Index == INDEX_NONE || !RemembranceSubsystem)
    {
        return false;
    }

    const FLITD2ArchiveVisualReconstruction& Definition = Reconstructions[Index];
    ULITD2RemembranceReconstruction* RuntimeDefinition = NewObject<ULITD2RemembranceReconstruction>(this);
    RuntimeDefinition->ReconstructionId = Definition.ReconstructionId;
    RuntimeDefinition->Title = Definition.Title;
    RuntimeDefinition->RequiredEntryIds = Definition.RequiredEntryIds;
    RuntimeDefinition->AlternativeRequirementGroups = Definition.AlternativeRequirementGroups;
    RuntimeDefinition->ResultEntryId = Definition.ResultEntryId;
    RuntimeDefinition->Unlocks = Definition.Unlocks;

    if (!RemembranceSubsystem->ApplyReconstruction(RuntimeDefinition))
    {
        return false;
    }

    RemembranceSubsystem->SaveArchives();
    SelectedEntryId = Definition.ResultEntryId;
    ReconstructionPulseEntryId = Definition.ResultEntryId;
    ReconstructionPulseSeconds = 1.35f;
    KnowledgeRevealSeconds = KnowledgeRevealDuration;
    KnowledgeRevealTitle = Definition.Title;
    KnowledgeRevealExplanation = Definition.Unlocks.Num() > 0
        ? Definition.Unlocks[0].Explanation
        : FText::FromString(TEXT("Une nouvelle relation de la Dernière Guerre vient d'être comprise."));
    EntryRevealSeconds.FindOrAdd(Definition.ResultEntryId) = 1.6f;
    TriggerDossierTransition();
    PlayUISound(ReconstructionSound);
    InvalidateLayoutAndVolatility();
    return true;
}

void ULITD2RemembranceArchiveScreen::HandleEntryChanged(
    FName EntryId,
    ELITD2RemembranceDiscoveryState NewState)
{
    if (!EntryId.IsNone() && NewState != ELITD2RemembranceDiscoveryState::Unknown)
    {
        EntryRevealSeconds.FindOrAdd(EntryId) = 1.15f;
        InvalidateLayoutAndVolatility();
    }
}

void ULITD2RemembranceArchiveScreen::HandleReconstructionCompleted(FName ReconstructionId)
{
    for (const FLITD2ArchiveVisualReconstruction& Reconstruction : Reconstructions)
    {
        if (Reconstruction.ReconstructionId == ReconstructionId)
        {
            ReconstructionPulseEntryId = Reconstruction.ResultEntryId;
            ReconstructionPulseSeconds = FMath::Max(ReconstructionPulseSeconds, 1.35f);
            break;
        }
    }
}

void ULITD2RemembranceArchiveScreen::NativeTick(const FGeometry& MyGeometry, float InDeltaTime)
{
    Super::NativeTick(MyGeometry, InDeltaTime);

    ArchiveAgeSeconds += InDeltaTime;
    DossierTransitionSeconds = FMath::Max(0.0f, DossierTransitionSeconds - InDeltaTime);
    ReconstructionPulseSeconds = FMath::Max(0.0f, ReconstructionPulseSeconds - InDeltaTime);
    KnowledgeRevealSeconds = FMath::Max(0.0f, KnowledgeRevealSeconds - InDeltaTime);

    TArray<FName> CompletedReveals;
    for (TPair<FName, float>& Pair : EntryRevealSeconds)
    {
        Pair.Value = FMath::Max(0.0f, Pair.Value - InDeltaTime);
        if (Pair.Value <= KINDA_SMALL_NUMBER)
        {
            CompletedReveals.Add(Pair.Key);
        }
    }
    for (const FName EntryId : CompletedReveals)
    {
        EntryRevealSeconds.Remove(EntryId);
    }

    // The archive intentionally remains volatile while open: ash, filaments and
    // the low breathing pulse are part of the Remanence presentation language.
    InvalidateLayoutAndVolatility();
}

FLinearColor ULITD2RemembranceArchiveScreen::CategoryColor(const FString& Category) const
{
    if (Category == TEXT("Body")) return FLinearColor(0.50f, 0.09f, 0.08f, 1.0f);
    if (Category == TEXT("Mind")) return FLinearColor(0.82f, 0.82f, 0.75f, 1.0f);
    if (Category == TEXT("Politics")) return FLinearColor(0.64f, 0.47f, 0.19f, 1.0f);
    if (Category == TEXT("Medicine")) return FLinearColor(0.82f, 0.69f, 0.63f, 1.0f);
    if (Category == TEXT("Technology")) return FLinearColor(0.52f, 0.57f, 0.61f, 1.0f);
    if (Category == TEXT("Person")) return FLinearColor(0.76f, 0.60f, 0.38f, 1.0f);
    if (Category == TEXT("Faction")) return FLinearColor(0.52f, 0.38f, 0.20f, 1.0f);
    if (Category == TEXT("Place") || Category == TEXT("City")) return FLinearColor(0.42f, 0.36f, 0.27f, 1.0f);
    return FLinearColor(0.25f, 0.23f, 0.22f, 1.0f);
}

FString ULITD2RemembranceArchiveScreen::DisplayState(ELITD2RemembranceDiscoveryState State) const
{
    switch (State)
    {
        case ELITD2RemembranceDiscoveryState::Trace: return TEXT("TRACE");
        case ELITD2RemembranceDiscoveryState::Documented: return TEXT("DOCUMENTÉ");
        case ELITD2RemembranceDiscoveryState::Reconstructed: return TEXT("RECONSTRUIT");
        case ELITD2RemembranceDiscoveryState::Contested: return TEXT("CONTESTÉ");
        default: return TEXT("INCONNU");
    }
}

FString ULITD2RemembranceArchiveScreen::ReliabilityLabel(const FString& Reliability) const
{
    if (Reliability == TEXT("Confirmed")) return TEXT("Confirmé");
    if (Reliability == TEXT("Probable")) return TEXT("Probable");
    if (Reliability == TEXT("Contested")) return TEXT("Contesté");
    if (Reliability == TEXT("SingleTestimony")) return TEXT("Témoignage unique");
    if (Reliability == TEXT("ProbablePropaganda")) return TEXT("Propagande probable");
    return TEXT("Incertain");
}

int32 ULITD2RemembranceArchiveScreen::NativePaint(
    const FPaintArgs& Args,
    const FGeometry& AllottedGeometry,
    const FSlateRect& MyCullingRect,
    FSlateWindowElementList& OutDrawElements,
    int32 LayerId,
    const FWidgetStyle& InWidgetStyle,
    bool bParentEnabled) const
{
    const int32 SuperLayer = Super::NativePaint(
        Args,
        AllottedGeometry,
        MyCullingRect,
        OutDrawElements,
        LayerId,
        InWidgetStyle,
        bParentEnabled);

    int32 Layer = FMath::Max(LayerId, SuperLayer) + 1;
    const FVector2D Size = AllottedGeometry.GetLocalSize();
    const double GraphWidth = Size.X * GraphWidthRatio;
    const double PanelX = GraphWidth + 10.0;
    const double PanelWidth = FMath::Max(220.0, Size.X - PanelX - 12.0);
    const float IntroAlpha = Smooth01(ArchiveAgeSeconds / FMath::Max(0.1f, IntroDuration));
    const float ThreadReveal = Smooth01((ArchiveAgeSeconds - 0.18f) / FMath::Max(0.1f, ThreadRevealDuration));
    const float Breathing = 0.5f + 0.5f * FMath::Sin(ArchiveAgeSeconds * 0.72f);

    // Deep-black documentary surface with a warmer central memory field.
    DrawSolidBox(OutDrawElements, Layer, AllottedGeometry, FVector2D::ZeroVector, Size, FLinearColor(0.006f, 0.006f, 0.009f, 0.995f));
    DrawSolidBox(OutDrawElements, Layer + 1, AllottedGeometry, FVector2D(0.0, 0.0), FVector2D(GraphWidth, Size.Y), FLinearColor(0.024f, 0.017f, 0.019f, 0.96f * IntroAlpha));

    // Fine archival striations keep the screen tactile without becoming a grid.
    for (int32 Stripe = 0; Stripe < 10; ++Stripe)
    {
        const double Y = Size.Y * (0.08 + Stripe * 0.092);
        DrawLine(
            OutDrawElements,
            Layer + 2,
            AllottedGeometry,
            FVector2D(18.0, Y),
            FVector2D(GraphWidth - 20.0, Y + FMath::Sin(ArchiveAgeSeconds * 0.18f + Stripe) * 2.0f),
            FLinearColor(0.32f, 0.23f, 0.18f, 0.025f * IntroAlpha),
            1.0f);
    }

    // Procedural ash/dust: tiny, slow particles that never obscure the documents.
    for (int32 Mote = 0; Mote < AshMoteCount; ++Mote)
    {
        const float SeedX = Hash01(Mote * 17 + 3);
        const float SeedY = Hash01(Mote * 31 + 11);
        const float SeedSpeed = Hash01(Mote * 47 + 7);
        const float Drift = FMath::Sin(ArchiveAgeSeconds * (0.18f + SeedSpeed * 0.21f) + Mote) * (8.0f + SeedSpeed * 12.0f);
        const float Speed = 4.0f + SeedSpeed * 11.0f;
        const float Y = FMath::Fmod(SeedY * Size.Y + Size.Y - FMath::Fmod(ArchiveAgeSeconds * Speed, Size.Y), Size.Y);
        const float X = SeedX * GraphWidth + Drift;
        const float MoteSize = 1.0f + Hash01(Mote * 61 + 5) * 1.7f;
        const float Alpha = (0.035f + Hash01(Mote * 73 + 2) * 0.09f) * IntroAlpha;
        DrawSolidBox(
            OutDrawElements,
            Layer + 3,
            AllottedGeometry,
            FVector2D(X, Y),
            FVector2D(MoteSize, MoteSize),
            FLinearColor(0.76f, 0.61f, 0.40f, Alpha));
    }

    DrawTextLine(OutDrawElements, Layer + 8, AllottedGeometry, FVector2D(28.0, 20.0), TEXT("ARCHIVES DE RÉMANENCE"), 22, FLinearColor(0.72f, 0.57f, 0.28f, IntroAlpha), true);
    DrawTextLine(OutDrawElements, Layer + 8, AllottedGeometry, FVector2D(28.0, 49.0), TEXT("Certaines traces peuvent être reliées."), 11, FLinearColor(0.64f, 0.61f, 0.56f, IntroAlpha));

    // Relationship layer: threads grow out of the known nodes instead of popping in.
    for (const FLITD2ArchiveVisualNode& Node : Nodes)
    {
        if (!IsNodeVisible(Node))
        {
            continue;
        }
        const FVector2D Start = GetNodeLocalPosition(Node, Size);

        for (const FName RelatedId : Node.RelatedEntryIds)
        {
            const int32* RelatedIndex = NodeIndexById.Find(RelatedId);
            if (!RelatedIndex || !IsNodeVisible(Nodes[*RelatedIndex]) || Node.EntryId.ToString() >= RelatedId.ToString())
            {
                continue;
            }

            const float PairPhase = ArchiveAgeSeconds * 0.9f + Hash01(GetTypeHash(Node.EntryId) ^ GetTypeHash(RelatedId)) * PI * 2.0f;
            const FLinearColor ThreadColor(0.52f, 0.40f, 0.23f, (0.24f + Breathing * 0.14f) * IntroAlpha);
            DrawThread(
                OutDrawElements,
                Layer + 4,
                AllottedGeometry,
                Start,
                GetNodeLocalPosition(Nodes[*RelatedIndex], Size),
                ThreadReveal,
                PairPhase,
                ThreadColor,
                1.15f);
        }

        for (const FName ContradictionId : Node.ContradictionEntryIds)
        {
            const int32* OtherIndex = NodeIndexById.Find(ContradictionId);
            if (!OtherIndex || !IsNodeVisible(Nodes[*OtherIndex]) || Node.EntryId.ToString() >= ContradictionId.ToString())
            {
                continue;
            }

            const float ContradictionPulse = 0.72f + 0.28f * FMath::Sin(ArchiveAgeSeconds * 2.3f);
            DrawDashedLine(
                OutDrawElements,
                Layer + 5,
                AllottedGeometry,
                Start,
                GetNodeLocalPosition(Nodes[*OtherIndex], Size),
                FLinearColor(0.70f, 0.10f, 0.08f, ContradictionPulse * IntroAlpha),
                1.9f,
                ThreadReveal);
        }
    }

    const FVector2D BaseNodeSize(164.0, 64.0);
    for (int32 NodeIndex = 0; NodeIndex < Nodes.Num(); ++NodeIndex)
    {
        const FLITD2ArchiveVisualNode& Node = Nodes[NodeIndex];
        if (!IsNodeVisible(Node))
        {
            continue;
        }

        const ELITD2RemembranceDiscoveryState State = GetNodeState(Node);
        const FVector2D Center = GetNodeLocalPosition(Node, Size);
        const FLinearColor Accent = CategoryColor(Node.Category);
        const bool bSelected = Node.EntryId == SelectedEntryId;
        const bool bUnknown = State == ELITD2RemembranceDiscoveryState::Unknown;
        const float Entrance = Smooth01((ArchiveAgeSeconds - 0.22f - NodeIndex * 0.045f) / 0.38f);
        const float* RevealSeconds = EntryRevealSeconds.Find(Node.EntryId);
        const float RevealPulse = RevealSeconds ? FMath::Clamp(*RevealSeconds / 1.15f, 0.0f, 1.0f) : 0.0f;
        const float SelectedPulse = bSelected ? (0.35f + Breathing * 0.28f) : 0.0f;
        const float Scale = 0.88f + 0.12f * Entrance + RevealPulse * 0.08f;
        const FVector2D NodeSize = BaseNodeSize * Scale;
        const FVector2D TopLeft = Center - NodeSize * 0.5;
        const float NodeAlpha = IntroAlpha * Entrance;

        // Living halo + off-register shadow makes the cards feel remembered, not diagrammatic.
        DrawSolidBox(
            OutDrawElements,
            Layer + 8,
            AllottedGeometry,
            TopLeft - FVector2D(7.0, 5.0),
            NodeSize + FVector2D(14.0, 10.0),
            Accent.CopyWithNewOpacity((0.035f + SelectedPulse * 0.14f + RevealPulse * 0.18f) * NodeAlpha));

        DrawSolidBox(
            OutDrawElements,
            Layer + 9,
            AllottedGeometry,
            TopLeft + FVector2D(5.0, 5.0),
            NodeSize,
            FLinearColor(0.0f, 0.0f, 0.0f, 0.48f * NodeAlpha));

        const FLinearColor FrameColor = bSelected
            ? FLinearColor(0.80f, 0.61f, 0.27f, 0.92f * NodeAlpha)
            : Accent.CopyWithNewOpacity(0.74f * NodeAlpha);
        DrawSolidBox(OutDrawElements, Layer + 10, AllottedGeometry, TopLeft - FVector2D(2.0, 2.0), NodeSize + FVector2D(4.0, 4.0), FrameColor);
        DrawSolidBox(
            OutDrawElements,
            Layer + 11,
            AllottedGeometry,
            TopLeft,
            NodeSize,
            bUnknown
                ? FLinearColor(0.014f, 0.014f, 0.018f, 0.985f * NodeAlpha)
                : FLinearColor(0.050f, 0.035f, 0.039f, 0.985f * NodeAlpha));

        // Irregular memory-card silhouette: asymmetric side bones and category seed.
        DrawSolidBox(OutDrawElements, Layer + 12, AllottedGeometry, TopLeft + FVector2D(-5.0, 8.0), FVector2D(5.0, NodeSize.Y * 0.53), Accent.CopyWithNewOpacity(0.62f * NodeAlpha));
        DrawSolidBox(OutDrawElements, Layer + 12, AllottedGeometry, TopLeft + FVector2D(NodeSize.X, NodeSize.Y * 0.62), FVector2D(7.0, 3.0), Accent.CopyWithNewOpacity(0.52f * NodeAlpha));
        DrawSolidBox(OutDrawElements, Layer + 12, AllottedGeometry, TopLeft + FVector2D(10.0, 13.0), FVector2D(7.0, 7.0), Accent.CopyWithNewOpacity(0.88f * NodeAlpha));
        DrawSolidBox(OutDrawElements, Layer + 12, AllottedGeometry, TopLeft + FVector2D(8.0, NodeSize.Y - 4.0), FVector2D(NodeSize.X * 0.28, 2.0), Accent.CopyWithNewOpacity(0.45f * NodeAlpha));

        DrawTextLine(
            OutDrawElements,
            Layer + 13,
            AllottedGeometry,
            TopLeft + FVector2D(23.0, 9.0),
            bUnknown ? TEXT("????????") : Node.Title.ToString(),
            12,
            bUnknown ? FLinearColor(0.50f, 0.48f, 0.45f, NodeAlpha) : FLinearColor(0.92f, 0.86f, 0.76f, NodeAlpha),
            true);
        DrawTextLine(
            OutDrawElements,
            Layer + 13,
            AllottedGeometry,
            TopLeft + FVector2D(23.0, 37.0),
            DisplayState(State),
            9,
            Accent.CopyWithNewOpacity(NodeAlpha));

        if (ReconstructionPulseSeconds > 0.0f && Node.EntryId == ReconstructionPulseEntryId)
        {
            const float Alpha = FMath::Clamp(ReconstructionPulseSeconds / 1.35f, 0.0f, 1.0f);
            const double Expansion = (1.0 - Alpha) * 48.0;
            DrawSolidBox(
                OutDrawElements,
                Layer + 14,
                AllottedGeometry,
                TopLeft - FVector2D(Expansion, Expansion),
                NodeSize + FVector2D(Expansion * 2.0, Expansion * 2.0),
                FLinearColor(0.88f, 0.69f, 0.29f, Alpha * 0.16f));
        }
    }

    // Dossier slides in after each selection; the graph remains visible underneath.
    const float DossierAlpha = 1.0f - Smooth01(DossierTransitionSeconds / FMath::Max(0.05f, DossierTransitionDuration));
    const double DossierSlide = (1.0 - DossierAlpha) * 46.0;
    const double AnimatedPanelX = PanelX + DossierSlide;
    DrawSolidBox(
        OutDrawElements,
        Layer + 18,
        AllottedGeometry,
        FVector2D(AnimatedPanelX, 10.0),
        FVector2D(PanelWidth, Size.Y - 20.0),
        FLinearColor(0.032f, 0.022f, 0.025f, 0.985f * IntroAlpha));
    DrawSolidBox(
        OutDrawElements,
        Layer + 19,
        AllottedGeometry,
        FVector2D(AnimatedPanelX, 10.0),
        FVector2D(2.0, Size.Y - 20.0),
        FLinearColor(0.62f, 0.45f, 0.20f, (0.35f + Breathing * 0.20f) * IntroAlpha));

    DrawTextLine(
        OutDrawElements,
        Layer + 20,
        AllottedGeometry,
        FVector2D(AnimatedPanelX + 24.0, 30.0),
        TEXT("DOSSIER"),
        15,
        FLinearColor(0.70f, 0.53f, 0.25f, DossierAlpha),
        true);
    double PanelY = 65.0;

    const FLITD2ArchiveVisualNode* SelectedNode = nullptr;
    if (const int32* SelectedIndex = NodeIndexById.Find(SelectedEntryId))
    {
        SelectedNode = &Nodes[*SelectedIndex];
    }

    if (SelectedNode)
    {
        const ELITD2RemembranceDiscoveryState State = GetNodeState(*SelectedNode);
        const bool bUnknown = State == ELITD2RemembranceDiscoveryState::Unknown;
        const FLinearColor Accent = CategoryColor(SelectedNode->Category);

        DrawTextLine(
            OutDrawElements,
            Layer + 20,
            AllottedGeometry,
            FVector2D(AnimatedPanelX + 24.0, PanelY),
            bUnknown ? TEXT("????????") : SelectedNode->Title.ToString(),
            18,
            FLinearColor(0.93f, 0.85f, 0.72f, DossierAlpha),
            true);
        PanelY += 31.0;
        DrawTextLine(
            OutDrawElements,
            Layer + 20,
            AllottedGeometry,
            FVector2D(AnimatedPanelX + 24.0, PanelY),
            SelectedNode->Category.ToUpper() + TEXT("  •  ") + DisplayState(State),
            10,
            Accent.CopyWithNewOpacity(DossierAlpha));
        PanelY += 24.0;
        DrawTextLine(
            OutDrawElements,
            Layer + 20,
            AllottedGeometry,
            FVector2D(AnimatedPanelX + 24.0, PanelY),
            TEXT("Fiabilité : ") + ReliabilityLabel(SelectedNode->Reliability),
            10,
            FLinearColor(0.64f, 0.61f, 0.56f, DossierAlpha));
        PanelY += 35.0;

        if (!bUnknown)
        {
            const int32 MaxChars = FMath::Clamp(static_cast<int32>(PanelWidth / 7.2), 28, 58);
            TArray<FString> DescriptionLines = WrapWords(SelectedNode->Description.ToString(), MaxChars);
            if (DescriptionLines.Num() > 10)
            {
                DescriptionLines.SetNum(10);
                DescriptionLines.Last() += TEXT("…");
            }
            for (const FString& DescriptionLine : DescriptionLines)
            {
                DrawTextLine(
                    OutDrawElements,
                    Layer + 20,
                    AllottedGeometry,
                    FVector2D(AnimatedPanelX + 24.0, PanelY),
                    DescriptionLine,
                    11,
                    FLinearColor(0.80f, 0.77f, 0.70f, DossierAlpha));
                PanelY += 18.0;
            }

            int32 KnownSourceCount = 0;
            if (RemembranceSubsystem)
            {
                for (const FName SourceId : SelectedNode->SourceIds)
                {
                    KnownSourceCount += RemembranceSubsystem->HasDiscoveredSource(SourceId) ? 1 : 0;
                }
            }

            PanelY += 20.0;
            DrawTextLine(
                OutDrawElements,
                Layer + 20,
                AllottedGeometry,
                FVector2D(AnimatedPanelX + 24.0, PanelY),
                FString::Printf(TEXT("Sources connues : %d / %d"), KnownSourceCount, SelectedNode->SourceIds.Num()),
                10,
                FLinearColor(0.58f, 0.55f, 0.50f, DossierAlpha));
            PanelY += 19.0;
            DrawTextLine(
                OutDrawElements,
                Layer + 20,
                AllottedGeometry,
                FVector2D(AnimatedPanelX + 24.0, PanelY),
                FString::Printf(TEXT("Connexions : %d"), SelectedNode->RelatedEntryIds.Num()),
                10,
                FLinearColor(0.58f, 0.55f, 0.50f, DossierAlpha));
            PanelY += 19.0;

            if (SelectedNode->ContradictionEntryIds.Num() > 0)
            {
                const float WarningPulse = 0.72f + 0.28f * FMath::Sin(ArchiveAgeSeconds * 2.5f);
                DrawTextLine(
                    OutDrawElements,
                    Layer + 20,
                    AllottedGeometry,
                    FVector2D(AnimatedPanelX + 24.0, PanelY),
                    TEXT("CONTRADICTION DÉTECTÉE"),
                    10,
                    FLinearColor(0.78f, 0.15f, 0.11f, DossierAlpha * WarningPulse),
                    true);
            }
        }
        else
        {
            DrawTextLine(
                OutDrawElements,
                Layer + 20,
                AllottedGeometry,
                FVector2D(AnimatedPanelX + 24.0, PanelY),
                TEXT("La relation existe, mais son sens reste inconnu."),
                11,
                FLinearColor(0.55f, 0.52f, 0.48f, DossierAlpha));
        }
    }
    else
    {
        DrawTextLine(
            OutDrawElements,
            Layer + 20,
            AllottedGeometry,
            FVector2D(AnimatedPanelX + 24.0, PanelY),
            TEXT("Sélectionnez une trace."),
            12,
            FLinearColor(0.64f, 0.61f, 0.56f, DossierAlpha));
    }

    const int32 AvailableReconstruction = FindAvailableReconstruction();
    if (AvailableReconstruction != INDEX_NONE)
    {
        const FVector2D ButtonPosition(AnimatedPanelX + 22.0, Size.Y - 84.0);
        const FVector2D ButtonSize(PanelWidth - 44.0, 48.0);
        const float ButtonPulse = 0.80f + Breathing * 0.20f;
        DrawSolidBox(
            OutDrawElements,
            Layer + 20,
            AllottedGeometry,
            ButtonPosition - FVector2D(2.0, 2.0),
            ButtonSize + FVector2D(4.0, 4.0),
            FLinearColor(0.72f, 0.49f, 0.17f, 0.42f * ButtonPulse * DossierAlpha));
        DrawSolidBox(
            OutDrawElements,
            Layer + 21,
            AllottedGeometry,
            ButtonPosition,
            ButtonSize,
            FLinearColor(0.38f, 0.21f, 0.07f, 0.98f * DossierAlpha));
        DrawTextLine(
            OutDrawElements,
            Layer + 22,
            AllottedGeometry,
            ButtonPosition + FVector2D(15.0, 14.0),
            TEXT("RECONSTRUIRE — ") + Reconstructions[AvailableReconstruction].Title.ToString(),
            10,
            FLinearColor(0.97f, 0.85f, 0.57f, DossierAlpha),
            true);
    }

    DrawTextLine(
        OutDrawElements,
        Layer + 20,
        AllottedGeometry,
        FVector2D(28.0, Size.Y - 30.0),
        TEXT("Clic : inspecter   •   glisser : déplacer   •   molette : zoom"),
        9,
        FLinearColor(0.49f, 0.46f, 0.42f, IntroAlpha));

    // Full-screen knowledge reveal: short, ceremonial, then gives control back.
    if (KnowledgeRevealSeconds > 0.0f)
    {
        const float Progress = 1.0f - KnowledgeRevealSeconds / FMath::Max(0.5f, KnowledgeRevealDuration);
        const float FadeIn = Smooth01(Progress / 0.16f);
        const float FadeOut = Smooth01(KnowledgeRevealSeconds / 0.42f);
        const float RevealAlpha = FMath::Min(FadeIn, FadeOut);
        const float LightSweep = FMath::Clamp((Progress - 0.12f) / 0.62f, 0.0f, 1.0f);
        const FVector2D RevealSize(FMath::Min(720.0, Size.X * 0.62), 190.0);
        const FVector2D RevealTopLeft = Size * 0.5 - RevealSize * 0.5;

        DrawSolidBox(
            OutDrawElements,
            Layer + 40,
            AllottedGeometry,
            FVector2D::ZeroVector,
            Size,
            FLinearColor(0.006f, 0.005f, 0.008f, 0.70f * RevealAlpha));
        DrawSolidBox(
            OutDrawElements,
            Layer + 41,
            AllottedGeometry,
            RevealTopLeft - FVector2D(3.0, 3.0),
            RevealSize + FVector2D(6.0, 6.0),
            FLinearColor(0.80f, 0.61f, 0.25f, 0.50f * RevealAlpha));
        DrawSolidBox(
            OutDrawElements,
            Layer + 42,
            AllottedGeometry,
            RevealTopLeft,
            RevealSize,
            FLinearColor(0.035f, 0.024f, 0.027f, 0.985f * RevealAlpha));

        const double SweepWidth = RevealSize.X * 0.22;
        const double SweepX = RevealTopLeft.X - SweepWidth + (RevealSize.X + SweepWidth * 2.0) * LightSweep;
        DrawSolidBox(
            OutDrawElements,
            Layer + 43,
            AllottedGeometry,
            FVector2D(SweepX, RevealTopLeft.Y + 2.0),
            FVector2D(SweepWidth, RevealSize.Y - 4.0),
            FLinearColor(0.92f, 0.77f, 0.43f, 0.055f * RevealAlpha));

        DrawTextLine(
            OutDrawElements,
            Layer + 44,
            AllottedGeometry,
            RevealTopLeft + FVector2D(30.0, 28.0),
            TEXT("CONNAISSANCE RECONSTRUITE"),
            12,
            FLinearColor(0.79f, 0.61f, 0.29f, RevealAlpha),
            true);
        DrawTextLine(
            OutDrawElements,
            Layer + 44,
            AllottedGeometry,
            RevealTopLeft + FVector2D(30.0, 59.0),
            KnowledgeRevealTitle.ToString(),
            21,
            FLinearColor(0.96f, 0.88f, 0.73f, RevealAlpha),
            true);

        const int32 MaxChars = FMath::Clamp(static_cast<int32>((RevealSize.X - 60.0) / 7.0), 42, 92);
        TArray<FString> RevealLines = WrapWords(KnowledgeRevealExplanation.ToString(), MaxChars);
        if (RevealLines.Num() > 3)
        {
            RevealLines.SetNum(3);
            RevealLines.Last() += TEXT("…");
        }
        double RevealY = 102.0;
        for (const FString& Line : RevealLines)
        {
            DrawTextLine(
                OutDrawElements,
                Layer + 44,
                AllottedGeometry,
                RevealTopLeft + FVector2D(30.0, RevealY),
                Line,
                11,
                FLinearColor(0.80f, 0.76f, 0.68f, RevealAlpha));
            RevealY += 18.0;
        }
    }

    return Layer + 48;
}

FReply ULITD2RemembranceArchiveScreen::NativeOnMouseButtonDown(
    const FGeometry& InGeometry,
    const FPointerEvent& InMouseEvent)
{
    if (InMouseEvent.GetEffectingButton() != EKeys::LeftMouseButton)
    {
        return Super::NativeOnMouseButtonDown(InGeometry, InMouseEvent);
    }

    // The reconstruction reveal is deliberately short and non-interruptible.
    if (KnowledgeRevealSeconds > 0.0f)
    {
        return FReply::Handled();
    }

    const FVector2D LocalPosition = InGeometry.AbsoluteToLocal(InMouseEvent.GetScreenSpacePosition());
    const FVector2D Size = InGeometry.GetLocalSize();
    const double GraphWidth = Size.X * GraphWidthRatio;
    const double PanelX = GraphWidth + 10.0;
    const double PanelWidth = FMath::Max(220.0, Size.X - PanelX - 12.0);

    const int32 AvailableReconstruction = FindAvailableReconstruction();
    if (AvailableReconstruction != INDEX_NONE)
    {
        const FVector2D ButtonPosition(PanelX + 22.0, Size.Y - 84.0);
        const FVector2D ButtonSize(PanelWidth - 44.0, 48.0);
        if (LocalPosition.X >= ButtonPosition.X && LocalPosition.X <= ButtonPosition.X + ButtonSize.X &&
            LocalPosition.Y >= ButtonPosition.Y && LocalPosition.Y <= ButtonPosition.Y + ButtonSize.Y)
        {
            TryReconstructAvailable();
            return FReply::Handled();
        }
    }

    if (LocalPosition.X <= GraphWidth)
    {
        const int32 HitIndex = HitTestNode(InGeometry, LocalPosition);
        if (HitIndex != INDEX_NONE)
        {
            SelectEntry(Nodes[HitIndex].EntryId);
            return FReply::Handled();
        }

        bDraggingGraph = true;
        LastDragLocal = LocalPosition;
        return FReply::Handled().CaptureMouse(TakeWidget());
    }

    return FReply::Unhandled();
}

FReply ULITD2RemembranceArchiveScreen::NativeOnMouseButtonUp(
    const FGeometry& InGeometry,
    const FPointerEvent& InMouseEvent)
{
    if (InMouseEvent.GetEffectingButton() == EKeys::LeftMouseButton && bDraggingGraph)
    {
        bDraggingGraph = false;
        return FReply::Handled().ReleaseMouseCapture();
    }
    return Super::NativeOnMouseButtonUp(InGeometry, InMouseEvent);
}

FReply ULITD2RemembranceArchiveScreen::NativeOnMouseMove(
    const FGeometry& InGeometry,
    const FPointerEvent& InMouseEvent)
{
    if (!bDraggingGraph)
    {
        return Super::NativeOnMouseMove(InGeometry, InMouseEvent);
    }

    const FVector2D LocalPosition = InGeometry.AbsoluteToLocal(InMouseEvent.GetScreenSpacePosition());
    PanOffset += LocalPosition - LastDragLocal;
    LastDragLocal = LocalPosition;
    InvalidateLayoutAndVolatility();
    return FReply::Handled();
}

FReply ULITD2RemembranceArchiveScreen::NativeOnMouseWheel(
    const FGeometry& InGeometry,
    const FPointerEvent& InMouseEvent)
{
    const FVector2D LocalPosition = InGeometry.AbsoluteToLocal(InMouseEvent.GetScreenSpacePosition());
    const FVector2D Size = InGeometry.GetLocalSize();
    const double GraphWidth = Size.X * GraphWidthRatio;
    if (LocalPosition.X > GraphWidth)
    {
        return Super::NativeOnMouseWheel(InGeometry, InMouseEvent);
    }

    const float PreviousZoom = Zoom;
    Zoom = FMath::Clamp(Zoom * FMath::Pow(1.14f, InMouseEvent.GetWheelDelta()), MinZoom, MaxZoom);
    if (!FMath::IsNearlyEqual(PreviousZoom, Zoom))
    {
        const FVector2D Center(GraphWidth * 0.5, Size.Y * 0.5);
        const FVector2D GraphPointBeforeZoom = (LocalPosition - Center - PanOffset) / PreviousZoom;
        PanOffset = LocalPosition - Center - GraphPointBeforeZoom * Zoom;
        InvalidateLayoutAndVolatility();
    }

    return FReply::Handled();
}
