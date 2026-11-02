import Login from "./Login";
import { useRoute } from "./router";
import { logOut, useSession } from "./auth";
import Shell from "./Shell";
import { Button, Spinner } from "./ui";
import AIRecipe from "./views/AIRecipe";
import Friends from "./views/Friends";
import Messages from "./views/Messages";
import MyRecipes from "./views/MyRecipes";
import Profile from "./views/Profile";
import Reminders from "./views/Reminders";
import Stores from "./views/Stores";

function Screen() {
  const route = useRoute();
  switch (route.name) {
    case "stores":
      return <Stores />;
    case "reminders":
      return <Reminders userStoreId={route.userStoreId} />;
    case "friends":
      return <Friends />;
    case "messages":
      return <Messages conversationId={route.conversationId} />;
    case "ai-recipe":
      return <AIRecipe />;
    case "recipes":
      return <MyRecipes />;
    case "profile":
      return <Profile />;
  }
}

export default function Root() {
  const session = useSession();
  const route = useRoute();

  if (session.status === "loading") {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <Spinner label="Opening Allim…" />
      </div>
    );
  }
  if (session.status === "signedOut") return <Login />;
  if (session.status === "noProfile") {
    return (
      <div className="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center gap-4 px-6 text-center">
        <p className="text-[17px] text-ink">
          {session.firebaseUser.email} is signed in, but has no Allim profile yet. Finish signing up
          in the iOS or Android app, then sign in here again.
        </p>
        <Button variant="secondary" onClick={logOut}>
          Sign out
        </Button>
      </div>
    );
  }
  return (
    <Shell route={route}>
      <Screen />
    </Shell>
  );
}
