import PhoneFrame from "../PhoneFrame";
import { SHOT, SHOT_FRAME, shotSources } from "./shot";

interface Props {
  /** The screenshot's file name in public/, without its extension. */
  shot: string;
  alt: string;
}

/**
 * A phone holding nothing but a screenshot. The shot carries the app's own
 * status bar and home indicator, so the frame draws neither.
 */
export default function ShotPhone({ shot, alt }: Props) {
  return (
    <PhoneFrame chrome={false} width={SHOT_FRAME.width} height={SHOT_FRAME.height}>
      <img
        {...shotSources(shot)}
        width={SHOT.width}
        height={SHOT.height}
        alt={alt}
        className="h-full w-full object-cover"
        /* Below the fold, and React preloads any img that isn't lazy. */
        loading="lazy"
        draggable={false}
      />
    </PhoneFrame>
  );
}
