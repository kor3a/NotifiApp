import {
  ownerSharing,
  recipientsFrom,
  sharedWithChange,
  withLookedUpNames,
} from '../storeSharing';

const doc = (userId: string, userName?: string) => ({
  data: () => ({userId, userName}),
});
const named = (...names: string[]) => ({
  count: names.length,
  names,
  unnamedIds: [],
});

describe('recipientsFrom', () => {
  it('counts every recipient and notes who has no name', () => {
    expect(recipientsFrom([doc('a', 'Leah'), doc('b')])).toEqual({
      count: 2,
      names: ['Leah'],
      unnamedIds: ['b'],
    });
  });
});

describe('withLookedUpNames', () => {
  const unnamed = {count: 2, names: ['Tom'], unnamedIds: ['leah', 'gone']};

  it('adds the names the lookup found', () => {
    expect(withLookedUpNames(unnamed, new Map([['leah', 'Leah']]))).toEqual({
      count: 2,
      names: ['Tom', 'Leah'],
      unnamedIds: ['gone'],
    });
  });

  it('changes nothing when the lookup found nobody', () => {
    expect(withLookedUpNames(unnamed, new Map())).toEqual(unnamed);
  });
});

describe('ownerSharing', () => {
  it('shows a store as shared when its only recipient has no name', () => {
    const recipients = {count: 1, names: [], unnamedIds: ['a']};
    expect(ownerSharing(recipients, []).isShared).toBe(true);
  });

  it('prefers the recipients names over stale stored ones', () => {
    expect(ownerSharing(named('Leah'), ['Old']).names).toEqual(['Leah']);
  });

  it('keeps the stored names while a recipient is unnamed', () => {
    const recipients = {count: 1, names: [], unnamedIds: ['a']};
    expect(ownerSharing(recipients, ['Leah']).names).toEqual(['Leah']);
  });

  it('shows a store as not shared once nobody is left', () => {
    expect(ownerSharing(named(), ['Leah'])).toEqual({
      names: [],
      isShared: false,
    });
  });

  it('goes by the stored names until recipients have loaded', () => {
    expect(ownerSharing(undefined, ['Leah'])).toEqual({
      names: ['Leah'],
      isShared: true,
    });
  });
});

describe('sharedWithChange', () => {
  it('does not erase the stored names because a recipient has no name', () => {
    const recipients = {count: 1, names: [], unnamedIds: ['a']};
    expect(sharedWithChange(recipients, ['Leah'])).toBeNull();
  });

  it('restores a name that was lost once it has been looked up', () => {
    const lookedUp = withLookedUpNames(
      {count: 1, names: [], unnamedIds: ['leah']},
      new Map([['leah', 'Leah']]),
    );
    expect(sharedWithChange(lookedUp, [])).toEqual({
      type: 'set',
      names: ['Leah'],
    });
  });

  it('keeps a stored name that could belong to someone still unnamed', () => {
    const recipients = {count: 2, names: ['Tom'], unnamedIds: ['a']};
    expect(sharedWithChange(recipients, ['Leah'])).toEqual({
      type: 'set',
      names: ['Tom', 'Leah'],
    });
  });

  it('writes nothing while nobody can be named and nothing is stored', () => {
    const recipients = {count: 1, names: [], unnamedIds: ['a']};
    expect(sharedWithChange(recipients, [])).toBeNull();
  });

  it('replaces the stored names once everyone is accounted for', () => {
    expect(sharedWithChange(named('Leah'), ['Old'])).toEqual({
      type: 'set',
      names: ['Leah'],
    });
  });

  it('clears the stored names when the last recipient has gone', () => {
    expect(sharedWithChange(named(), ['Leah'])).toEqual({type: 'clear'});
  });

  it('writes nothing when there was nothing to clear', () => {
    expect(sharedWithChange(named(), [])).toBeNull();
  });

  it('writes nothing when the same names are stored in another order', () => {
    expect(sharedWithChange(named('Leah', 'Tom'), ['Tom', 'Leah'])).toBeNull();
  });
});
