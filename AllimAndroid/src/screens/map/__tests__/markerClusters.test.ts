import {
  BranchMarker,
  clusterMarkers,
  MAX_VISIBLE_MARKERS,
  MIN_CLUSTER_ZOOM_DELTA,
  regionForCluster,
  visibleClusters,
} from '../markerClusters';
import {UserStoreItem} from '../../../models';

jest.mock('react-native-maps', () => ({}));

const SCREEN_WIDTH = 360;

function marker(
  storeId: string,
  latitude: number,
  longitude: number,
  reminderCount = 0,
): BranchMarker {
  return {
    item: {
      id: storeId,
      store: {id: storeId, name: storeId, reminderCount},
    } as UserStoreItem,
    branch: {
      id: `${latitude}_${longitude}`,
      name: storeId,
      latitude,
      longitude,
    },
  };
}

function regionAt(delta: number) {
  return {
    latitude: 0,
    longitude: 0,
    latitudeDelta: delta,
    longitudeDelta: delta,
  };
}

describe('clusterMarkers', () => {
  // At a 0.05 delta on a 360 dp screen, 44 dp is about 0.006 degrees.
  const region = regionAt(0.05);

  it('keeps markers that would not overlap apart', () => {
    const clusters = clusterMarkers(
      [marker('a', 0, 0), marker('b', 0.02, 0.02)],
      region,
      SCREEN_WIDTH,
    );
    expect(clusters).toHaveLength(2);
  });

  it('groups markers that would overlap', () => {
    const clusters = clusterMarkers(
      [marker('a', 0, 0), marker('b', 0.001, 0.001)],
      region,
      SCREEN_WIDTH,
    );
    expect(clusters).toHaveLength(1);
    expect(clusters[0].members).toHaveLength(2);
  });

  it('separates a group when zoomed in', () => {
    const markers = [marker('a', 0, 0), marker('b', 0.001, 0.001)];
    expect(clusterMarkers(markers, regionAt(0.005), SCREEN_WIDTH)).toHaveLength(
      2,
    );
  });

  it('leads a group with the store that has the most reminders', () => {
    const clusters = clusterMarkers(
      [marker('few', 0, 0, 1), marker('many', 0.001, 0, 8)],
      region,
      SCREEN_WIDTH,
    );
    expect(clusters[0].item.id).toBe('many');
  });

  it('picks the same lead whatever order the markers arrive in', () => {
    const a = marker('a', 0, 0, 2);
    const b = marker('b', 0.001, 0, 2);
    expect(clusterMarkers([a, b], region, SCREEN_WIDTH)[0].id).toBe(
      clusterMarkers([b, a], region, SCREEN_WIDTH)[0].id,
    );
  });

  it('reduces a dense zoomed-out map to a few groups', () => {
    const many = Array.from({length: 120}, (_, i) =>
      marker(`store${i}`, (i % 12) * 0.01, Math.floor(i / 12) * 0.01),
    );
    expect(
      clusterMarkers(many, regionAt(2), SCREEN_WIDTH).length,
    ).toBeLessThanOrEqual(2);
  });
});

describe('visibleClusters', () => {
  const region = regionAt(0.05);

  it('leaves out groups well outside the view', () => {
    const clusters = clusterMarkers(
      [marker('near', 0.01, 0), marker('far', 1, 1)],
      region,
      SCREEN_WIDTH,
    );
    expect(visibleClusters(clusters, region).map(c => c.item.id)).toEqual([
      'near',
    ]);
  });

  it('never returns more than the limit, keeping the nearest', () => {
    const wide = regionAt(100);
    const clusters = Array.from({length: 60}, (_, i) =>
      marker(`store${i}`, i * 0.5, 0),
    ).map(m => ({...m, id: m.item.id, members: [m.branch]}));
    const visible = visibleClusters(clusters, wide);
    expect(visible).toHaveLength(MAX_VISIBLE_MARKERS);
    expect(visible[0].item.id).toBe('store0');
    expect(visible.some(c => c.item.id === 'store59')).toBe(false);
  });
});

describe('regionForCluster', () => {
  it('centres on the group and fits every branch', () => {
    const region = regionForCluster([
      marker('a', 0, 0).branch,
      marker('b', 0.1, 0.2).branch,
    ]);
    expect(region.latitude).toBeCloseTo(0.05);
    expect(region.longitude).toBeCloseTo(0.1);
    expect(region.latitudeDelta).toBeGreaterThan(0.1);
    expect(region.longitudeDelta).toBeGreaterThan(0.2);
  });

  it('does not zoom in past the limit for branches almost on top of each other', () => {
    const region = regionForCluster([
      marker('a', 0, 0).branch,
      marker('b', 0.00001, 0.00001).branch,
    ]);
    expect(region.latitudeDelta).toBe(MIN_CLUSTER_ZOOM_DELTA);
    expect(region.longitudeDelta).toBe(MIN_CLUSTER_ZOOM_DELTA);
  });
});
