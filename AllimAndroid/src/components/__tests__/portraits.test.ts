import {guessGender, portraitFor} from '../portraits';

const portrait = (index: number) =>
  require(`../../../assets/images/portraits/portrait-${index}.png`);

describe('guessGender', () => {
  it('reads the first name', () => {
    expect(guessGender('James Jeon')).toBe('male');
    expect(guessGender('  sarah  ')).toBe('female');
  });

  it('handles accents and hyphens', () => {
    expect(guessGender('José Álvarez')).toBe('male');
    expect(guessGender('Min-jun Park')).toBe('male');
    expect(guessGender('Mary-Jane Watson')).toBe('female');
  });

  it('leaves unisex and unknown names alone', () => {
    expect(guessGender('Alex Kim')).toBeNull();
    expect(guessGender('Jordan')).toBeNull();
    expect(guessGender('전재민')).toBeNull();
  });
});

describe('portraitFor', () => {
  it('has nothing for an empty name', () => {
    expect(portraitFor(undefined)).toBeNull();
    expect(portraitFor('   ')).toBeNull();
  });

  it('draws men and women from their own sets', () => {
    for (const name of ['James Jeon', 'Michael', 'Haruto Sato', 'Omar']) {
      const pick = portraitFor(name);
      expect([0, 1, 2, 3].map(portrait)).toContainEqual(pick);
    }
    for (const name of ['Sarah Lee', 'Seoyeon', 'Priya Patel', 'Sofia']) {
      const pick = portraitFor(name);
      expect([4, 5, 6, 7].map(portrait)).toContainEqual(pick);
    }
  });

  it('gives unknown names the same face iOS does', () => {
    // Expected values from PortraitAvatar.variant(for:) on iOS.
    expect(portraitFor('Alex Kim')).toEqual(portrait(0));
    expect(portraitFor('Jordan')).toEqual(portrait(3));
    expect(portraitFor('전재민')).toEqual(portrait(1));
    expect(portraitFor('Sam')).toEqual(portrait(6));
  });

  it('is stable for a given name', () => {
    expect(portraitFor('Sarah Lee')).toEqual(portraitFor(' Sarah Lee '));
  });
});
