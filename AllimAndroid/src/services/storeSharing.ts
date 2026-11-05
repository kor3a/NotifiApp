// How a store's sharing state follows from the people who accepted it. Each
// recipient has a user_store pointing at the owner's, and that document existing
// is what makes the store shared. Its `userName` is only a label, and older
// documents don't have one, so a recipient can be real and still have no name.

export interface StoreRecipients {
  count: number;
  names: string[];
  // Recipients whose documents carry no name, for looking the name up elsewhere.
  unnamedIds: string[];
}

export function recipientsFrom(
  docs: {data(): {userName?: string; userId?: string}}[],
): StoreRecipients {
  const names: string[] = [];
  const unnamedIds: string[] = [];
  docs.forEach(doc => {
    const {userName, userId} = doc.data();
    if (userName) {
      names.push(userName);
    } else if (userId) {
      unnamedIds.push(userId);
    }
  });
  return {count: docs.length, names, unnamedIds};
}

// Fills in the names found by looking up the unnamed recipients. Anyone the
// lookup didn't find stays unnamed.
export function withLookedUpNames(
  recipients: StoreRecipients,
  found: Map<string, string>,
): StoreRecipients {
  return {
    count: recipients.count,
    names: [
      ...recipients.names,
      ...recipients.unnamedIds
        .map(id => found.get(id))
        .filter((name): name is string => !!name),
    ],
    unnamedIds: recipients.unnamedIds.filter(id => !found.get(id)),
  };
}

// What an owned store shows. Until its recipients have loaded, the names stored
// on the owner's document are all there is to go on.
export function ownerSharing(
  recipients: StoreRecipients | undefined,
  storedNames: string[],
): {names: string[]; isShared: boolean} {
  if (!recipients) {
    return {names: storedNames, isShared: storedNames.length > 0};
  }
  return {
    names: recipients.count === 0 ? [] : namesToKeep(recipients, storedNames),
    isShared: recipients.count > 0,
  };
}

// While anyone is still unnamed the list is known to be short, and a stored name
// could be theirs, so stored names are only dropped once everyone is accounted
// for.
function namesToKeep(
  recipients: StoreRecipients,
  storedNames: string[],
): string[] {
  return recipients.names.length < recipients.count
    ? [...new Set([...recipients.names, ...storedNames])]
    : recipients.names;
}

// The write that brings the owner's stored names in line with its recipients.
// iOS reads only this list to mark a store as shared, so it has to be right. It's
// cleared only when nobody is left, never because the people who are there have
// no names on file.
export function sharedWithChange(
  recipients: StoreRecipients,
  storedNames: string[],
): {type: 'clear'} | {type: 'set'; names: string[]} | null {
  if (recipients.count === 0) {
    return storedNames.length > 0 ? {type: 'clear'} : null;
  }
  const names = namesToKeep(recipients, storedNames);
  const unchanged =
    storedNames.length === names.length &&
    names.every(name => storedNames.includes(name));
  return unchanged ? null : {type: 'set', names};
}
