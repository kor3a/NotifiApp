import PhoneFrame from "../PhoneFrame";
import { SHOT, SHOT_FRAME } from "./shot";

interface Props {
  src: string;
  alt: string;
}

/**
 * A phone holding nothing but a screenshot. The shot carries the app's own
 * status bar and home indicator, so the frame draws neither.
 */
export default function ShotPhone({ src, alt }: Props) {
  return (
    <PhoneFrame chrome={false} width={SHOT_FRAME.width} height={SHOT_FRAME.height}>
      <img
        src={src}
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
