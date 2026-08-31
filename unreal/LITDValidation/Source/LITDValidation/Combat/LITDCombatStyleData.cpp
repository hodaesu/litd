#include "Combat/LITDCombatStyleData.h"

FName ULITDCombatStyleData::ResolveEntryActionId(const ELITDCombatStance Stance, const ELITDCombatInput Input) const
{
    for (const FLITDStyleEntryAction& Entry : EntryActions)
    {
        if (Entry.Stance == Stance && Entry.Input == Input)
        {
            return Entry.ActionId;
        }
    }
    return NAME_None;
}
