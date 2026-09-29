--
-- Coffee Maker (coffee_maker.adb)
-- created 2026 September 11
-- updated 2026 September 28
--
-- A simple parser adventure.  Written in Ada.  Using simple, table-based
-- global data structures.  An experiment to see how well that works.
--
-- I am not an Ada expert.  I have surely used techniques & style that
-- stray from the Ada community's best practies.
--

with Ada.Integer_Text_IO;               use Ada.Integer_Text_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;                  use Ada.Strings.Maps;
with Ada.Strings.Unbounded;             use Ada.Strings.Unbounded;
with Ada.Strings;                       use Ada.Strings;
with Ada.Text_IO;                       use Ada.Text_IO;

procedure coffee_maker is
  --
  -- Because I'm tired of fixing compiler errors by typing
  -- Put(To_String(...)).
  --
  procedure Put( S : Unbounded_String ) is
  begin
    Put( To_String(S) );
  end Put;
  procedure Put_Line( S : Unbounded_String ) is
  begin
    Put_Line( To_String(S) );
  end Put_Line;

  --
  -- All the Things in the world.  This includes the avatar, rooms, Things
  -- that can be in the rooms, the NO_SUCH_THING, & even verbs.
  --
  -- I've put grouped & ordered these to make it easy for me.  The
  -- order is insignificant within the program.
  --
  -- Yep, verbs are Things in this game.  It makes it easy for the parser
  -- to have a single dictionary.  The dictionary needn't care whether a
  -- word refers to an object or a verb.  The dictionary is simply a
  -- map of words to Thing_Id.  The 2-word parser distinguishes between
  -- verbs & objects by position, but that's the only distinction; other
  -- than position, it can use the same dictionary for verbs & objects.
  --
  -- The technique worked well for a 2-word parser.  I don't know that it
  -- would be as appropriate for a more complex parser.
  --
  type Thing_Id is (
    NO_SUCH_THING,
	NO_SUCH_VERB,
    UNSUPPLIED,
	AVATAR,
    --
    -- ROOMS
    HERE_ROOM,  -- alias for current room
    KITCHEN_ROOM,
    DINING_ROOM,
    LIBRARY_ROOM,
    LOUNGE_ROOM,
    BASEMENT_ROOM,
    SUN_ROOM,
    --
    -- VERBS
	DOWN_VERB,
	EAST_VERB,
	LOOK_VERB,
	NORTH_VERB,
	SOUTH_VERB,
	UP_VERB,
	WALK_VERB,
	WEST_VERB,
    DRINK_VERB,
    DROP_VERB,
    INVENTORY_VERB,
    LOCK_VERB,
    MAKE_VERB, -- only for "make coffee"
    READ_VERB,
    SEARCH_VERB,
    TAKE_VERB,
    UNLOCK_VERB,
    USE_VERB,
    WASH_VERB,
    WIPE_VERB,
    --
    -- THINGS, some takeable, some not
	CLEAN_FUNNEL,
	DIRTY_MUG,
	GROUND_COFFEE,
	KETTLE,
    CLEAN_MUG,
    DIRTY_FUNNEL,
    KITTY,
    MUG_OF_COFFEE,
    NOTE,
    SACK_OF_FOODSTUFFS
  );
	
  --
  -- So we can Put(X) where X is a Thing_id.
  --
  package Thing_Id_IO is new Ada.Text_IO.Enumeration_IO( Thing_Id );
  use Thing_Id_IO;

  --
  -- Bit-flags for every object.  You can create these to show what's
  -- Takeable, what's illuminated (lit so Avatar can see), what's
  -- to be excluded from a list of contents of a room, or any other
  -- Boolean attributes you want for all Things.
  --
  type Flags_Type is array(Thing_Id) of Boolean;

  --
  -- Strings for every object.  Use lists of this type for
  -- names & descriptions.  There may be other uses.
  --
  type Strings_Type is array(Thing_Id) of Unbounded_String;

  --
  -- Map a Thing to another Thing.  A main use of this is location.
  --
  type Thing_To_Thing_Type is array(Thing_Id) of Thing_Id;

  --
  -- Parsing an input string produces a Command with all its
  -- parts filled.  An unspecified part will have NO_SUCH_THING
  -- for its id.
  --
  -- We're using a 2-word parser, so a Command has a verb & an
  -- object.  For each, we keep the actual string (word) & the
  -- Thing_Id.
  --
  type Command_Type is record
    Verb_Str : Unbounded_String := To_Unbounded_String( "" );
    Verb_Id : Thing_Id := UNSUPPLIED;
    Object_Str : Unbounded_String  := To_Unbounded_String( "" );
    Object_Id : Thing_Id := UNSUPPLIED;
  end record;
  procedure Put( C : Command_Type ) is
  begin
    Put( "Command_Type( Verb_Str => """ );
    Put( To_String(C.Verb_Str) );
    Put( """, Verb_Id => " );
    Put( C.Verb_Id );
    Put( ", Object_Str => """ );
    Put( To_String(C.Object_Str) );
    Put( """, Object_Id => " );
    Put( C.Object_Id );
    Put(" )" );
  end Put;

  --
  -- An Action is a procedure that acts on a Command.
  --
  type Action_Ptr is access procedure( C : Command_Type );

  --
  -- A list of Thing-to-Action.  Use this to map verb Things to
  -- Actions (procedures).  All other Things also map to Actions,
  -- but it's the Not_A_Verb Action.
  --
  type Actions_Type is array(Thing_Id) of Action_Ptr;

  --
  -- Main loop keeps going until this is true.
  -- User makes this true to entering "@quit".
  --
  Is_Done: Boolean := False;

  --
  -- Names of every object
  --
  Name : Strings_Type := (
    AVATAR => To_Unbounded_String("you"),
    BASEMENT_ROOM => To_Unbounded_String("in the basement"),
    CLEAN_FUNNEL => To_Unbounded_String("a pour-over funnel that's ready to make coffee"),
    CLEAN_MUG => To_Unbounded_String("a large, clean coffee mug"),
    DINING_ROOM => To_Unbounded_String("the dining room"),
    DROP_VERB => To_Unbounded_String("the drop verb"),
    DIRTY_FUNNEL => To_Unbounded_String("a pour-over funnel that needs cleaning"),
    GROUND_COFFEE => To_Unbounded_String("some ground coffee"),
    INVENTORY_VERB => To_Unbounded_String("the inventory verb"),
    KETTLE => To_Unbounded_String("an electric kettle"),
    KITCHEN_ROOM => To_Unbounded_String("in the kitchen"),
    LOUNGE_ROOM => To_Unbounded_String("in the lounge"),
    MAKE_VERB => To_Unbounded_String("the make verb"),
    DIRTY_MUG => To_Unbounded_String("a large, dirty coffee mug"),
    NOTE => To_Unbounded_String("a hand-written note"),
    NO_SUCH_THING => To_Unbounded_String("no such object"),
    SACK_OF_FOODSTUFFS => To_Unbounded_String("a sack of drygoods from the grocery store"),
    TAKE_VERB => To_Unbounded_String("the take verb"),
    WASH_VERB => To_Unbounded_String("the wash verb"),
    WIPE_VERB => To_Unbounded_String("the wipe verb"),
    others => To_Unbounded_String("<<noname>>")
  );

  -- 
  -- DESCRIPTIONS (possibly multi-line) of each Thing.
  --
  Desc: Strings_Type := (
    AVATAR => To_Unbounded_String("a respectable person"),
    BASEMENT_ROOM => To_Unbounded_String(
      "You are in the basement.  It's dark, but there are no grues.  Such" &
	  " luck!  The room is large & unfinished.  The floor is cinderblock" &
	  " with a thick coat of dry dust.  The walls are brick & coated with" &
      " nearly as much dust.  Several thick columns of brick prevent" &
      " the ceiling from collapsing."
    ),
    CLEAN_MUG => To_Unbounded_String(
      "It's a coffee mug.  It's clean enough to drink from if there were" &
      " coffee in it."
    ),
    DINING_ROOM => To_Unbounded_String(
      "You are in the dining room.  There's a wooden table in the center" &
      " of the room.  The kitchen is to the south."
    ),
    DROP_VERB => To_Unbounded_String(
      "This is the object that implements the Drop action.  You should" &
      " no be seeing this."
    ),
    INVENTORY_VERB => To_Unbounded_String(
      "This is the object that implements the Inventory action.  You should" &
      " no be seeing this."
    ),
    KETTLE => To_Unbounded_String(
      "It's an electric kettle.  The barrel is glass.  Its lid is hinged." &
	  "  It has a base with bumps & slots, looks like they fit into a" &
      " custom stand."
    ),
    KITCHEN_ROOM => To_Unbounded_String(
      "You are in a huge kitchen with red-brick walls.  It has ovens" &
	  " embedded into the walls, three on each side.  There's a table" &
      " near the center of the room.  On the table are a stand for an" &
      " electric kettle & a note next to it.  There are open doorways" &
      " to each of the 4 main compass directions (north, east, south" &
      " west)."
    ),
    LIBRARY_ROOM => To_Unbounded_String(
      "You are in the library.  Tall bookcases line the walls.  There's a" &
      " ladder on casters & attached to a rail that runs around the room" &
      " so that people (including you) can reach even the top shelves. " &
      " Good thing, that, as those shelves are too high for even the" &
      " tallest person you've ever met to reach.  The kitchen is to the" &
      " west."
    ),
    LOUNGE_ROOM => To_Unbounded_String(
      "You are in the lounge.  A large window on the west lets in sunlight" &
      " on bad days, twilight or moonlight when the weather is good.  It's" &
      " furnished with comfy chairs & a comfy couch, perfect for people to" &
      " take a seat with their coffee to talk or read quietly."
    ),
    MAKE_VERB => To_Unbounded_String(
      "This is the object that implements the Make action.  You should" &
      " not be seeing this."
    ),
    NOTE => To_Unbounded_String(
      "In an admirably controlled hand, someone has written" &
      " ""To make coffee, you will need the electric kettle, a mug," &
      " a pour-over funnel with built-in filter, & of course some ground" &
      " coffee."""
    ),
    SACK_OF_FOODSTUFFS => To_Unbounded_String(
      "It's a paper sack, like from a grocery story.  It's stuffed full" &
      " of drygoods (stuff that you can put on a shelf for weeks or" &
      " longer without it going bad).  You feel a temptation to SEARCH" &
      " this sack."
    ),
    SUN_ROOM => To_Unbounded_String(
      "You walk up the stairs & into a comfortably welcoming room, perfect" &
	  " for sipping coffee with the kitty & a friend.  Congratulations," &
      " you've completed the game!"
    ),
    TAKE_VERB => To_Unbounded_String(
      "This is the object that implements the Take action.  You should" &
      " no be seeing this."
    ),
    WASH_VERB => To_Unbounded_String(
      "This is the object that implements the Wash action.  You should" &
	  " not be seeing this."
    ),
    WIPE_VERB => To_Unbounded_String(
      "This is the object that implements the Wipe action.  You should" &
	  " not be seeing this."
    ),
    others => To_Unbounded_String("<<no desc>>")
  );

  --
  -- Locations of every object.  Rooms & verbs aren't anywhere, so
  -- their locations are NO_SUCH_THING.
  --
  Location : Thing_To_Thing_Type := (
    AVATAR => KITCHEN_ROOM,
    KETTLE => DINING_ROOM,
    DIRTY_FUNNEL => LIBRARY_ROOM,
    DIRTY_MUG => LOUNGE_ROOM,
    NOTE => KITCHEN_ROOM,
    SACK_OF_FOODSTUFFS => BASEMENT_ROOM,
    others => NO_SUCH_THING
  );

  --
  -- Flags to remember which rooms the avatar has entered
  --
  Here_Before : Flags_Type := (
    KITCHEN_ROOM => True,
    others => False
  );

  --
  -- The only Takeable things are ones we specify.  And during
  -- the game, it's okay for an object to change its Takeable flag.
  --
  -- Most Things, including rooms & verbs, are not Takeable.
  --
  Takeable : Flags_Type := (
    CLEAN_MUG => True,
    DIRTY_MUG => True,
    CLEAN_FUNNEL => True,
    DIRTY_FUNNEL => True,
    GROUND_COFFEE => True,
    KETTLE => True,
    SACK_OF_FOODSTUFFS => True,
    others => False
  );

  --
  -- Make objects droppable by default.  That should be okay even
  -- for objects that you can't Take.  (If you can't Take it in the
  -- first place, it doesn't hurt that you can Drop it... if you could
  -- take it.)
  --
  Dropable : Flags_Type := (
    MUG_OF_COFFEE => False,
    others => True
  );

  --
  -- Flags for rooms.  By default, a room emits light.  Set it to
  -- False here if it doesn't.  Without light, AVATAR must turn on
  -- the lights or carry an item that emits light.
  --
  Illuminated : Flags_Type := (
    others => True
  );

  --
  -- Flags to indicate whether items emit light.  Few items do.
  -- Verbs can turn items on or off, making them emit or stop emitting.
  --
  Emits_Light : Flags_Type := (
    others => False
  );

  --
  -- The Map.  When the target is NO_SUCH_THING, it means you can't
  -- go that way.
  --
  Targets_North : Thing_To_Thing_Type := (
    KITCHEN_ROOM => DINING_ROOM,
    LOUNGE_ROOM => KITCHEN_ROOM,
    others => NO_SUCH_THING
  );
  Targets_East : Thing_To_Thing_Type := (
    KITCHEN_ROOM => LIBRARY_ROOM,
    LOUNGE_ROOM => KITCHEN_ROOM,
    others => NO_SUCH_THING
  );
  Targets_South : Thing_To_Thing_Type := (
    DINING_ROOM => KITCHEN_ROOM,
    KITCHEN_ROOM => LOUNGE_ROOM,
    others => NO_SUCH_THING
  );
  Targets_West : Thing_To_Thing_Type := (
    KITCHEN_ROOM => LOUNGE_ROOM,
    LIBRARY_ROOM => KITCHEN_ROOM,
    others => NO_SUCH_THING
  );
  Targets_Up : Thing_To_Thing_Type := (
    BASEMENT_ROOM => KITCHEN_ROOM,
    others => NO_SUCH_THING
  );
  Targets_Down : Thing_To_Thing_Type := (
    KITCHEN_ROOM => BASEMENT_ROOM,
    others => NO_SUCH_THING
  );

  --********************************************************************
  -- CONVENIENCE PREDICATES
  --

  --
  -- True if & only if the Avatar is carrying the Thing.
  -- In this game, that's simple: Is the Avatar the Thing's location.
  -- In future games, we might need to search containers that the
  -- Avatar is carrying, & those containers might contain more
  -- containers.
  --
  function Carries( X : Thing_Id ) return Boolean is
    Result : Boolean;
  begin
    if Location(X) = AVATAR then
      Result := True;
    else
      Result := False;
    end if;
    return Result;
  end Carries;

  --
  -- True if & only if the Avatar has access to the Thing.  To have
  -- access to the Thing, the Avatar holds it or it's in the same
  -- room as the Avatar.
  --
  function Has_Access_To( X : Thing_Id ) return Boolean is
    Result : Boolean;
  begin
    if Location(X) = AVATAR then
      Result := True;                   -- Avatar holds it
    elsif Location(X) = Location(AVATAR) then
      Result := True;                   -- same room as Avatar
    else
      Result := False;                  -- doesn't have access
    end if;
    return Result;
  end Has_Access_To;

  --
  -- True if & only if the room is illuminated or AVATAR is
  -- carrying (directly) an item that emits light.
  --
  function Is_Illuminated return Boolean is
    Result : Boolean;
  begin
    Result := Illuminated(Location(AVATAR));
    if not Result then
      -- The room itself isn't illuminated, so search AVATAR's inventory.
      for I in Thing_Id loop
        if Location(I) = AVATAR and EMITS_LIGHT(I) then
          Result := True;
        end if;
      end loop;
    end if;
    return Result;
  end Is_Illuminated;

  --********************************************************************
  -- Standardized or convenient subprograms
  --

  --
  -- Output an entire paragraph, word-wrapped.
  --
  -- Screen width is hard-coded into this procedure.  That's the
  -- WIDTH constant.  It should be shorter than the actual number
  -- of columns.  So, like, you have an 80-column display?  WIDTH
  -- should be 79 or 78 or, if you want margins, 72 or whatever
  -- else floats yer boat.
  --
  -- In the usual, non-pathological cases, it prints "slices".  Each
  -- slice ends on the last space possible to make the slice as long
  -- as possible without being longer than WIDTH.
  --
  -- The first slice may begin with one or more spaces.  That allows
  -- the caller to indent a paragraph.  Slices after the first will
  -- not begin with spaces.
  --
  -- If we can't find a space to keep the slice short enough, the slice
  -- ends up being WIDTH characters.  You can either live with that ugly
  -- output or learn to write normal text.
  --
  -- We don't treat punctuation specially.  We only consider spaces vs
  -- not-a-space.
  --
  -- We don't justify.
  --
  -- We don't consider horizontal tabs, form feeds, or newlines at all.
  -- The idea is that the paragraph contains alpha, numeric, punctuaton, &
  -- spaces.  Nothing more.  Nothing less.
  --
  -- Empty string prints as a newline.  (What you'd expect.)
  --
  -- CAVEATS
  --
  -- Q. What if there are trailing spaces?
  -- A. Don't know.  Didn't test.  Avoid doing it.
  --
  -- Q. What if there are double-spaces, such as between sentences?
  -- A. When they fall within a slice, they are printed as consecutive
  --    spaces.  When they become the divider between consecutive slices,
  --    we'll omit them from the beginning of the following slice.  So
  --    when we print that second slice, the first thing we'll print is
  --    its first non-space character.  For example, let's say the
  --    slice boundary falls on one of the spaces in "Sam.  I".  (Presumably,
  --    that's a tiny part of a longer paragraph.)  Then the first slice
  --    will end with "Sam.", which we'll print.  The second slice would
  --    begin with "  I", but we'll omit the leading spaces, so the
  --    second slice that we print will begin with "I" (followed by
  --    whatever else is in the presumably larger string).
  --
  -- IMPLEMENTATION
  --
  -- The logic here is that we keep track of the start & stop of the
  -- slice we'll print next.  We know that the first slice always
  -- starts with S'First.  We always must search for the end of the
  -- slice; it's no farther back than Start + WIDTH, but we want it to
  -- end before a space, if possible.
  --
  -- That first slice always begins with S'First, so it may begin with
  -- leading spaces to indent the paragraph.  We'll ensure that later
  -- slices don't begin with spaces.
  --
  -- I originally relied on Ada's Ada.Strings.Fixed.Index functions
  -- to search for the stop & start, but since they search full strings,
  -- I had to slice up my string, then convert their result into index
  -- into the larger string, S.  Caused bugs that I didn't feel like
  -- fixing.  At least, I think that's what my problem was.  So I converted
  -- to explicit, iterative searches.  In retrospective, these iterative
  -- searches might be a little faster than the Index functions because
  -- we know we are searching for a single character whereas the Index
  -- functions are searching for string patterns so probably use Boyer-Moore
  -- or something similar that, while faster for long patterns, is no faster
  -- for single characters & also has a setup cost.
  --
  procedure Paragraph( S : String ) is

    WIDTH : constant Positive := 79;

    --
	-- Return highest index in S such that
    -- it's not less than Start and
	-- it's not greater than Start + WIDTH and
	-- it's passed over spaces.
	--
    function Find_Stop( Start : Natural ) return Natural is
      Stop : Natural;
    begin
      if S'Last <= Start + WIDTH then
        -- Remaining string is no more than WIDTH so the remaining
        -- slice is the whole remaining string.
        Stop := S'Last;
      else
        Stop := Start + WIDTH;
        -- Search backwards to find a space character that can
		-- act as the divider between slices.
        loop
          exit when Stop <= Start + WIDTH/2;
          exit when S(Stop) = ' ';
          Stop := Stop - 1;
        end loop;
        -- We don't need to print the space we found, so backup the
		-- Stop to whatever is before it.  Except that it's possible
		-- there are consecutive spaces, so keep backing up if there
		-- are.  Except that we don't want to preceed Start, so Stop
		-- if we reach it.
		loop
          exit when Stop <= Start;
          exit when S(Stop) /= ' ';
          Stop := Stop - 1;
		end loop;
      end if;
      return Stop;
    end Find_Stop;

    --
	-- Begin with the most recent Stop & search for the next
	-- non-space character.  If we find nothing, you'll get
	-- S'Last + 1.
	--
    function Find_Start( Stop : Natural ) return Natural is
      -- Stop probably indexes the last non-space character in the
	  -- slice we just printed.  So we begin with the character that
	  -- follows it.  That's probably a space, & we'll skip spaces
	  -- until we find a non-space.
      Start : Natural := Stop + 1;
    begin
      loop
        exit when S'Last < Start;
        exit when S(Start) /= ' ';
        Start := Start + 1;
      end loop;
	  return Start;
    end Find_Start;

    Start : Natural := S'First;
    Stop : Natural;
  begin
    if S'Length = 0 then
      New_Line;
    else
      loop
        Stop := Find_Stop( Start );
        Put_Line( S(Start..Stop) );
        delay 0.1;
        exit when S'Last <= Stop;
        Start := Find_Start( Stop );
        exit when S'Last < Start;
      end loop;
    end if;
  end Paragraph;

  --
  -- Subcontract the work to Paragraph(String)
  --
  procedure Paragraph( S : Unbounded_String ) is
  begin
    Paragraph( To_String(S) );
  end Paragraph;

  --********************************************************************
  --
  -- Map words to Things.  The parser relies on this!  Notice that
  -- this single table is for objects as well as verbs.
  type Word_Thing_Tuple is record
    Name : Unbounded_String;
    Thing : Thing_Id;
  end record;
  type Word_Thing_Tuples_Type is array(Positive range <>) of Word_Thing_Tuple;

  Words : Word_Thing_Tuples_Type := (
    ( To_Unbounded_String(""), UNSUPPLIED ),
    ( To_Unbounded_String("bag"), SACK_OF_FOODSTUFFS ),
    ( To_Unbounded_String("cat"), KITTY ),
    ( To_Unbounded_String("coffee"), GROUND_COFFEE ),
    ( To_Unbounded_String("d"), DOWN_VERB ),
    ( To_Unbounded_String("down"), DOWN_VERB ),
    ( To_Unbounded_String("drink"), DRINK_VERB ),
    ( To_Unbounded_String("drop"), DROP_VERB ),
    ( To_Unbounded_String("drygoods"), SACK_OF_FOODSTUFFS ),
    ( To_Unbounded_String("e"), EAST_VERB ),
    ( To_Unbounded_String("east"), EAST_VERB ),
    ( To_Unbounded_String("electric"), KETTLE ),
    ( To_Unbounded_String("exam"), LOOK_VERB ),
    ( To_Unbounded_String("examine"), LOOK_VERB ),
    ( To_Unbounded_String("filter"), DIRTY_FUNNEL ),
    ( To_Unbounded_String("food"), SACK_OF_FOODSTUFFS ),
    ( To_Unbounded_String("foodstuffs"), SACK_OF_FOODSTUFFS ),
    ( To_Unbounded_String("funnel"), DIRTY_FUNNEL ),
    ( To_Unbounded_String("get"), TAKE_VERB ),
    ( To_Unbounded_String("go"), WALK_VERB ),
    ( To_Unbounded_String("groceries"), SACK_OF_FOODSTUFFS ),
    ( To_Unbounded_String("grounds"), GROUND_COFFEE ),
    ( To_Unbounded_String("here"), HERE_ROOM ),
    ( To_Unbounded_String("i"), INVENTORY_VERB ),
    ( To_Unbounded_String("invent"), INVENTORY_VERB ),
    ( To_Unbounded_String("inventory"), INVENTORY_VERB ),
    ( To_Unbounded_String("kettle"), KETTLE ),
    ( To_Unbounded_String("kitten"), KITTY ),
    ( To_Unbounded_String("kitty"), KITTY ),
    ( To_Unbounded_String("l"), LOOK_VERB ),
    ( To_Unbounded_String("lock"), LOCK_VERB ),
    ( To_Unbounded_String("look"), LOOK_VERB ),
    ( To_Unbounded_String("make"), MAKE_VERB ),
    ( To_Unbounded_String("me"), AVATAR ),
    ( To_Unbounded_String("mug"), DIRTY_MUG ), -- CLEAN_MUG
    ( To_Unbounded_String("n"), NORTH_VERB ),
    ( To_Unbounded_String("north"), NORTH_VERB ),
    ( To_Unbounded_String("note"), NOTE ),
    ( To_Unbounded_String("read"), READ_VERB ),
    ( To_Unbounded_String("rinse"), WASH_VERB ),
    ( To_Unbounded_String("s"), SOUTH_VERB ),
    ( To_Unbounded_String("sack"), SACK_OF_FOODSTUFFS ),
    ( To_Unbounded_String("search"), SEARCH_VERB ),
    ( To_Unbounded_String("self"), AVATAR ),
    ( To_Unbounded_String("south"), SOUTH_VERB ),
    ( To_Unbounded_String("take"), TAKE_VERB ),
    ( To_Unbounded_String("u"), UP_VERB ),
    ( To_Unbounded_String("unlock"), UNLOCK_VERB ),
    ( To_Unbounded_String("up"), UP_VERB ),
    ( To_Unbounded_String("use"), USE_VERB ),
    ( To_Unbounded_String("w"), WEST_VERB ),
    ( To_Unbounded_String("walk"), WALK_VERB ),
    ( To_Unbounded_String("wash"), WASH_VERB ),
    ( To_Unbounded_String("wipe"), WIPE_VERB ),
    ( To_Unbounded_String("west"), WEST_VERB )
  );

  --
  -- Return index of the word in the Words list.  If there's
  -- no such word, return 0.
  -- Use a binary search.
  --
  function Lookup_Word( W: Unbounded_String ) return Natural is
    Lo: Natural := Words'First;
    Hi: Natural := Words'Last;
    Mid: Natural;
    Max_Tries: Positive := Words'Length / 2;
    Tries: Natural := 0;
  begin
    if Lo /= 1 then
      Put_Line( "ERROR in Lookup_Word.  The lowest index of Words isn't 1." );
      raise Program_Error;
    end if;
    loop
      exit when Hi <= Lo;
      exit when Max_Tries < Tries;
      Mid := (Hi - Lo) / 2 + Lo;
      if Words(Mid).Name < W then
        Hi := Mid;
      elsif Words(Mid).Name = W then
        Lo := Mid; Hi := Mid;
      else
        Lo := Mid;
      end if;
      Tries := Tries + 1;
    end loop;
    if Lo = Hi and then Words(Lo).Name = W then
      return Lo;
    else
      return 0;
    end if;
  end Lookup_Word;

  --
  -- Use this to direct a word from the dictionary to a different
  -- object.
  --
  procedure Replace_Word( W0: String; Replacement: Thing_Id) is
    W: Unbounded_String := To_Unbounded_String(W0);
    I: Positive := Words'First;
  begin
    loop
      exit when Words'Last < I;
      exit when Words(I).Name = W;
      I := I + 1;
    end loop;
    if Words'Last < I then
      Put_Line( "ERROR in Replace_Word.  We did not find an entry in Words" );
      Put( "for """ );
      Put( W );
      Put_Line( """." );
      raise Program_Error;
    end if;
    Words(I).Thing := Replacement;
  end Replace_Word;

  --
  -- Split a command line into words, storing them in a Command.
  -- Later parts of the program can bind the words to Things &
  -- store their Ids in the same Command.
  --
  -- Because our parser is limited to 2, 1, or 0 words, this
  -- Split_Into_Words function isn't general.  Also, it raises
  -- Too_Many_Words if there are more than 2 words.
  --
  -- Leading & trailing spaces are ignored.
  --
  -- Consecutive words are separated by on or more spaces.
  --
  -- Zero words is fine.  A missing word is stored as empty string
  -- in the Command.  So zero words stores two empty strings in the
  -- Command.
  --
  -- Examples:
  --
  -- Empty string is okay
  -- "" => ("", "")
  --
  -- "a" => ("a", "")
  --
  -- "abc" => ("abc", "")
  --
  -- Leading & trailing spaces are ignored:
  -- " a " => ("a", "")
  -- "      " => ("", "")
  --
  -- Two words...
  -- "a b" => ("a", "b")
  -- "word1 word2" => ("word1", "word2")
  -- "word1   word2" => ("word1", "word2")
  -- " word1   word2 " => ("word1", "word2")
  --
  -- Too many words...
  -- "one two three" => raise Too Many Words
  --
  Too_Many_Words : exception;
  function Split_Into_Words( Line : String ) return Command_Type is
    --
    -- Return true if & only of C is a space character.
    -- This implementation is strictly about spaces such as ASCII 32.  Future
    -- implementations could consider other characters as spaces; for
    -- example, horizontal tabs.
    function Is_Space( C : Character ) return Boolean is
      Result : Boolean;
    begin
      if C = ' ' then
        Result := True;
      else
        Result := False;
      end if;
      return Result;
    end Is_Space;

  -- My previous implementation used Find_Token, also removed tokens from
  -- the Line.  For a change, this implementation is non-destructive &
  -- does the work directly, not via the Find_Token subprogram.
  --
  Head : Positive;                      -- seek start of word
  After : Positive;                     -- after end of word
  --
  -- Keep track of which word we're looking for.  If we used a
  -- general purpose list of words, we'd simply accumulate into
  -- that list, but because we're cutting corners with that, we
  -- need to add these Boolean corners here.  These also allow
  -- us to detect a Too Many Words error situation.
  Need_Verb : Boolean := True;
  Need_Object : Boolean := True;
  --
  -- Our result
  C : Command_Type;
  begin
    Head := 1;
    loop
      exit when Line'Length < Head;
      --
      -- Skip spaces until we find start of word or end of string
      loop
        exit when Line'Length < Head;
        exit when not Is_Space(Line(Head));
        Head := Head + 1;
      end loop;
      --
      -- Search for first location after word.  That'll be past
      -- end of string or will be a character that's a space.  Head
      -- might already be after end of string; our loop takes that
      -- into account, though not explicitly.
      After := Head + 1;
      loop
        exit when Line'Length < After;
        exit when Is_Space(Line(After));
        After := After + 1;
      end loop;
      --
      -- Figure out what happened.  Maybe we found nothing.  Maybe we
      -- found a word.
      if Line'Length < Head then
        null;                           -- found nothing
      elsif Need_Verb then
        C.Verb_Str := To_Unbounded_String(Line(Head..After-1));
        Need_Verb := False;
      elsif Need_Object then
        C.Object_Str := To_Unbounded_String(Line(Head..After-1));
        Need_Object := False;
      else
        raise Too_Many_Words;
      end if;
      Head := After;
    end loop;
    return C;
  end Split_Into_Words;

  --
  -- On exit, the Verb_Id and Object_Id parts of the Command are
  -- filled with Thing_Ids.  We get them from the dictionary when
  -- possible.
  --
  procedure Bind_Words( C : in out Command_Type ) is
    --
    -- Perform a linear search through Words, looking for the word W.
	-- When found, Found0 gets True & I0 gets the index into Words.
    --
	-- Otherwise, Found0 gets False & I0 is undefined.  (Actually, I0
	-- gets Words'Last + 1, but you don't know that.  Treat it as
	-- undefined, unusable.)
    --
    -- If we had many words, we might want a binary search.
    --
    procedure Search_For_Word( W : Unbounded_String;
	                           I0 : out Positive;
							   Found0 : out Boolean )
    is
      I : Positive;
      Found : Boolean;
    begin
      Found := False;
      I := Words'First;
      loop
        if Words(I).Name = W then
          Found := True;
        end if;
        exit when Found;
        exit when Words'Last <= I;
        I := I + 1;
      end loop;
      I0 := I;
      Found0 := Found;
    end Search_For_Word;

    --
    -- On exit, C's Verb_Id has the Thing_Id of the verb.
    --
    procedure Bind_Verb( C : in out Command_Type ) is
      I : Positive;
      Found : Boolean;
    begin
      Search_For_Word( C.Verb_Str, I, Found );
      if Found then
        C.Verb_Id := Words(I).Thing;
      else
        C.Verb_Id := NO_SUCH_VERB;
      end if;
    end Bind_Verb;

    --
    -- On exit, C's Object_Id has the Thing_Id of the object,
	-- if there is one.  Otherwise, NO_SUCH_THING.
    --
    procedure Bind_Object( C : in out Command_Type ) is
      I : Positive;
      Found : Boolean;
    begin
      Search_For_Word( C.Object_Str, I, Found );
      if Found then
        C.Object_Id := Words(I).Thing;
      else
        C.Object_Id := NO_SUCH_THING;
      end if;
    end Bind_Object;

  begin
    Bind_Verb( C );
    Bind_Object( C );
  end Bind_Words;

  --
  --
  --
  procedure Parse( Line : String; C : out Command_Type ) is
  begin
    C := Split_Into_Words( Line );
    Bind_Words( C );
  end Parse;

  --********************************************************************
  -- Commonly used, standardized parts of verbs
  --

  procedure Look_Here is
    Here : Thing_Id;
    Is_First : Boolean;
    Is_Empty : Boolean;
    I : Thing_Id;
  begin
    Here := Location(AVATAR);
    Paragraph( Desc(HERE) );
    Is_First := True;
    Is_Empty := True;
    I := Thing_Id'First;
    loop
      if I = AVATAR then
        -- Don't bother to tell player that Avatar is here.
        null;
      elsif Location(I) = HERE then
        Is_Empty := False;
        if Is_First then
          Is_First := False;
          Put( "You see" );
        else
          Put( "," );
        end if;
        Put( " " );
        Put( Name(I) );
      end if;
      exit when I = Thing_Id'Last;
      I := Thing_Id'Succ(I);
    end loop;
    if not Is_Empty then
      Put( "." );
    end if;
    New_Line;
  end Look_Here;

  procedure Actually_Walk_Action( Targets : Thing_To_Thing_Type;
                                  C : Command_Type )
  is
    Target : Thing_Id;
  begin
    Target := Targets(Location(Avatar));
    if Target = NO_SUCH_THING then
      Put_Line( "You can't go that way." );
    elsif Here_Before(Target) then
      Location(Avatar) := Target;
      Put( "You are " );
      Put( Name(Target) );
      Put_Line( "." );
    else
      Location(Avatar) := Target;
      Here_Before(Target) := True;
      Look_Here;
    end if;
  end Actually_Walk_Action;

  --********************************************************************
  -- Actions, Verbs
  --

  --
  -- The special cases that distinguish this game from others.
  -- You can assume that verbs requiring objects have them.
  -- Verbs requiring objects that are carried... have them.
  -- Verbs requiring HAS ACCESS TO the object has it.
  --
  -- Return true if we have a special case & handled it.  Return
  -- false otherwise.
  --
  function Special_Actions( C : Command_Type )
  return Boolean
  is
    Result : Boolean := False;
    S : Unbounded_String;
  begin
    case C.Verb_Id is
    when DROP_VERB =>
      if Location(AVATAR) = KITCHEN_ROOM and C.Object_Id = KETTLE then
        -- Dropping the Kettle in the Kitchen places it in its stand &
        -- markes it as Not Takeable.
        Location(KETTLE) := KITCHEN_ROOM;
        Takeable(KETTLE) := False;
        Paragraph( "The electric kettle fits snuggly into its stand &" &
                   " is ready to boil water when you're ready to make" &
                   " coffee!" );
        Result := True;
      end if;
    when SEARCH_VERB =>
      case C.Object_Id is
	  when SACK_OF_FOODSTUFFS =>
        -- We move the Ground Coffee to wherever the Sack is.
		-- That works whether AVATAR searched the Sack where it
		-- was or was carrying it.
        Location(GROUND_COFFEE) := Location(SACK_OF_FOODSTUFFS);
        -- We no longer need the sack, so we move it to nowhere.
        Location(SACK_OF_FOODSTUFFS) := NO_SUCH_THING;
        Append( S, "Searching " );
        Append( S, Name(SACK_OF_FOODSTUFFS) );
        Append( S, " reveals " );
        Append( S, Name(GROUND_COFFEE) );
        Append( S, "!" );
        Paragraph( S );
        Result := True;
      when others => null;
      end case;
    when others => null;
    end case;
    return Result;
  end Special_Actions;

  --
  --
  --
  procedure Drink_Action( C : Command_Type ) is
  begin
    Put_Line( "FIXME Drink_Action" );
  end Drink_Action;

  procedure Drop_Action( C : Command_Type ) is
  begin
    if C.Object_Id = UNSUPPLIED then
      Put_Line( "Drop what?" );
    elsif C.Object_Id = NO_SUCH_THING then
      Put( "What is a " );
      Put( C.Object_Str );
      Put_Line( "?" );
    elsif not Carries(C.Object_Id) then
      Put( "You aren't carrying any " );
      Put( C.Object_Str );
      Put_Line( "." );
    elsif not Dropable(C.Object_Id) then
      Put( "It's impossible to drop " );
      Put( C.Object_Str );
      Put_Line( "!" );
    elsif Special_Actions(C) then
      -- It's a special case, & Special_Actions took care of it for us.
      null;
    else
      Location(C.Object_Id) := Location(AVATAR);
      Put( C.Object_Str );
      Put_Line( ": Dropped." );
    end if;
  end Drop_Action;

  procedure Take_Action( C : Command_Type ) is
  begin
    if C.Object_Id = UNSUPPLIED then
      Put_Line( "Take what?" );
    elsif C.Object_Id = NO_SUCH_THING then
      Put( "What is a " );
      Put( C.Object_Str );
      Put_Line( "?" );
    elsif Location(C.Object_Id) /= Location(AVATAR) then
      Put( "I don't see any " );
      Put( C.Object_Str );
      Put_Line( " here." );
    elsif not Takeable(C.Object_Id) then
      Put_Line( "You can't take that." );
    else
      Location(C.Object_Id) := AVATAR;
      Put( C.Object_Str );
      Put_Line( ": Taken." );
    end if;
  end Take_Action;

  procedure Inventory_Action( C : Command_Type ) is
    Count : Natural;
    Id : Thing_Id;
  begin
    --
    -- Count the items AVATAR carries.
    Count := 0;
    Id := Location'First;
    loop
      if Carries(Id) then
        Count := Count + 1;
      end if;
      exit when Id = Location'Last;
      Id := Thing_Id'Succ(Id);
    end loop;
    Put( "You are carrying " );
    Put( Count, Width => 0 );
    Put( " items." );
    if 1 <= Count then
      Put_Line( "  They are..." );
      Id := Location'First;
      loop
        if Carries(Id) then
          Put( "* " );
          Put( Name(Id) );
          New_Line;
        end if;
        exit when Id = Location'Last;
        Id := Thing_Id'Succ(Id);
    end loop;
      
    else
      New_Line;
    end if;
  end Inventory_Action;

  procedure Look_Action( C : Command_Type ) is

    procedure Look_At( C : Command_Type ) is
    begin
      if Has_Access_To(C.Object_Id) then
        Paragraph( Desc(C.Object_Id) );
      else
        Put( "I don't see any " );
        Put( C.Object_Str );
        Put_Line( " here." );
      end if;
    end Look_At;

  begin
    if not Is_Illuminated then
      Put_Line( "It's too dark to see anything." );
    elsif C.Object_Id = UNSUPPLIED or C.Object_Id = HERE_ROOM then
      Look_Here;
    else
      Look_At( C );
    end if;
  end Look_Action;

  procedure North_Action( C : Command_Type ) is
  begin
    Actually_Walk_Action( Targets_North, C );
  end North_Action;

  procedure East_Action( C : Command_Type ) is
  begin
    Actually_Walk_Action( Targets_East, C );
  end East_Action;

  procedure South_Action( C : Command_Type ) is
  begin
    Actually_Walk_Action( Targets_South, C );
  end South_Action;

  procedure West_Action( C : Command_Type ) is
  begin
    Actually_Walk_Action( Targets_West, C );
  end West_Action;

  procedure Up_Action( C : Command_Type ) is
  begin
    -- End-of-game is a special case, but we can detect it
    -- after the general purpose movement.  By doing the general
	-- state-changing action, then looking for the special case,
	-- it differs from all the other special cases.  They check
	-- for the special case early (not always first), before
	-- any state-changing code.
    Actually_Walk_Action( Targets_Up, C );
    --
	-- If the Avatar is in the Sun Room, the game is over.
	if Location(AVATAR) = SUN_ROOM then
      Is_Done := True;
    end if;
  end Up_Action;

  procedure Down_Action( C : Command_Type ) is
  begin
    Actually_Walk_Action( Targets_Down, C );
  end Down_Action;

  procedure Walk_Action( C : Command_Type ) is
  begin
    case C.Object_Id is
    when NORTH_VERB => North_Action( C );
    when EAST_VERB => East_Action( C );
    when SOUTH_VERB => South_Action( C );
    when WEST_VERB => West_Action( C );
    when UP_VERB => Up_Action( C );
    when DOWN_VERB => Down_Action( C );
    when others =>
      Put( """" );
      Put( C.Object_Str );
      Put( """ isn't a direction." );
    end case;
  end Walk_Action;

  --
  -- As part of this "parser game written in Ada" experiment, this is an
  -- interesting procedure because it has the most preconditions of any
  -- action in the game & the most side effects.
  --
  -- The preconditions include Avatar's location & the locations of
  -- the ground coffee, the kettle, the clean mug (which was created
  -- from the dirty mug), & the clean funnel (created from the dirty
  -- funnel).
  --
  -- All that is a way of saying that the procedure begins with a
  -- lengthy list of if/else arms.  When a precondition fails, we print a
  -- message that, we hope, tells the player what they need to do in
  -- the hopes of getting their next "make coffee" succeed.
  --
  procedure Make_Action( C : Command_Type ) is
    Target: constant Thing_Id := C.Object_Id;
  begin
    if Target /= GROUND_COFFEE then
      Paragraph( "You could make coffee if you have all 4 of the items &" &
                 " you are in the kitchen, but I'm not aware of anything" &
                 " else you could make in this game.  Sorry." );
    elsif Location(AVATAR) /= KITCHEN_ROOM then
      Paragraph( "The kitchen is the best place to make coffee." );
    elsif Location(KETTLE) /= KITCHEN_ROOM then
      Paragraph( "You'll need to drop an electric kettle on the electric" &
	             " kettle stand that's on the counter top over there." );
    elsif not Has_Access_To(CLEAN_MUG) then
      Paragraph( "You'll need to hold a clean mug or at least have one" &
                 " here in the kitchen." );
    elsif not Has_Access_To(CLEAN_FUNNEL) then
      Paragraph( "You'll need to carry a clean pour-over funnel, or at" &
                 " least have one here with you in the kitchen.  And" &
                 " it must be clean, not just a dirty old thing." );
    elsif not Has_Access_To(GROUND_COFFEE) then
      Paragraph( "You'll need to carry some ground coffee or have it" &
                 " here in the kitchen.  I mean, you can't make coffee" &
                 " without some ground coffee." );
    else
      Location(MUG_OF_COFFEE) := AVATAR;
      Location(CLEAN_MUG) := NO_SUCH_THING;
      Location(CLEAN_FUNNEL) := NO_SUCH_THING;
      Location(GROUND_COFFEE) := NO_SUCH_THING;
      Targets_Up(KITCHEN_ROOM) := SUN_ROOM;
      Replace_Word( "coffee", MUG_OF_COFFEE );
      Paragraph( "You fill the electric kettle with water from the faucet" &
                 " & start it.  You put the pour-over funnel on your mug &" &
				 " fill it with some ground coffee.  You wait..." );
      Paragraph( "When the water boils, you pour it into the filter &" &
                 " wait while it trickles into the mug." );
      Paragraph( "You now have a cup of steaming coffee!  It smells" &
                 " wonderful!" );
      Paragraph( "A kitty enters from some direction you didn't see," &
                 " meows, & runs up some stairs you hadn't noticed" &
                 " before.  There's a sun room up there, perfect for" &
                 " sipping coffee with a friend.  Someone is waiting for" &
                 " you up there." );
    end if;
  end Make_Action;

  --
  -- For this game, reading a target is the same as looking at it.
  -- In a more complex game, we could distinguish between the two.
  --
  procedure Read_Action( C : Command_Type ) is
    X : Thing_Id;
  begin
    X := C.Object_Id;
    if X = UNSUPPLIED then
      Put_Line( "Read what?" );
    elsif X = NO_SUCH_THING then
      Put( "What is a """ );
      Put( C.Object_Str );
      Put_Line( """?" );
    elsif Has_Access_To(X) then
      Paragraph( Desc(C.Object_Id) );
    else
      Put( "I don't see any " );
      Put( C.Object_Str );
      Put_Line( " here." );
    end if;
  end Read_Action;

  --
  -- Maybe I'm wrong about this, but what I think I've learned about
  -- Search from this experiment is that, when Search does something
  -- interesting, it moves the newly revealed object from No Such Thing
  -- (where the Avatar could not see it) to the current location.  It
  -- can also move an object from this location to No Such Thing, which
  -- this Search does.
  --
  -- When Search doesn't reveal something new, it prints that searching
  -- doesn't turn up anything useful.
  --
  -- A game could randomize the results, but be careful of never-ending
  -- failed searches.  If we want to randomize the results, we'll
  -- probably list all possible outcomes including failures, then
  -- shuffle the list.  Each search takes the next element from the
  -- list.  That way, the player is guaranteed to succeed before too
  -- long.
  --
  procedure Search_Action( C : Command_Type ) is
    S : Unbounded_String;
  begin
    if C.Object_Id = UNSUPPLIED then
      Put_Line( "Search what?" );
    elsif C.Object_Id = NO_SUCH_THING then
      Put( "What is a " );
      Put( C.Object_Str );
      Put_Line( "?" );
    elsif not Has_Access_To(C.Object_Id) then
      Paragraph( "You aren't carrying any " & To_String(C.Object_Str) &
                 ", & there isn't one here in the room." );
    elsif Special_Actions(C) then
      -- It's a special case, & Special_Actions took care of it for us.
      null;
    else
      Append( S, "Searching " );
      Append( S, C.Object_Str );
      Append( S, " doesn't reveal anything." );
      Paragraph( S );
    end if;    
  end Search_Action;

  --
  -- Like Search, makes use of the "move one object into hiding, move another
  -- object from hiding to here" trick.
  --
  procedure Wash_Action( C : Command_Type ) is
    Target: constant Thing_Id := C.Object_Id;
    S: Unbounded_String;
  begin
    if Target = NO_SUCH_THING then
      Append( S, "What is a " );
      Append( S, C.Object_Str );
      Append( S, "?" );
      Paragraph( S );
    elsif not Carries(Target) then
      Paragraph( "You can't wash it if you aren't carrying it." );
    elsif Location(AVATAR) /= KITCHEN_ROOM then
      Paragraph( "The only place around here for washing anything is" &
                 " the kitchen." );
    elsif Target = DIRTY_MUG then
      Location(CLEAN_MUG) := Location(DIRTY_MUG);
      Location(DIRTY_MUG) := NO_SUCH_THING;
      Replace_Word( "mug", CLEAN_MUG );
      Paragraph( "The formerly dirty mug is now clean enough for a drink." &
	             "  Excellent!" );
    elsif Target = DIRTY_FUNNEL then
      Location(CLEAN_FUNNEL) := Location(DIRTY_FUNNEL);
      Location(DIRTY_FUNNEL) := NO_SUCH_THING;
      Replace_Word( "funnel", CLEAN_FUNNEL );
      Replace_Word( "filter", CLEAN_FUNNEL );
      Paragraph( "The pour-over funnel is now clean & ready for making" &
	             " coffee.  Wonderful!" );
    else
      Paragraph( "It's cleaner than it was, always an improvement." );
    end if;
  end Wash_Action;

  --
  -- Not used in this game.
  --
  procedure Wipe_Action( C : Command_Type ) is
  begin
    Paragraph( "FIXME You wipe " & C.Object_Str & "." );
  end Wipe_Action;

  --
  -- Use this procedure for any object that should never be accepted
  -- as a verb.
  --
  procedure Not_A_Verb_Action( C : Command_Type ) is
  begin
    Put( """" );
	Put( C.Verb_Str );
	Put_Line( """ is not a verb!" );
  end Not_A_Verb_Action;

  --
  --
  --
  procedure Unsupplied_Action( C : Command_Type ) is
  begin
	Put_Line( "Hum dee dum dum do hum." );
  end Unsupplied_Action;

  --
  -- For each Thing, here's the address of a procedure to call when
  -- the player's Command specified that Thing as the verb.
  --
  Actions : Actions_Type := (
    DOWN_VERB => Down_Action'Access,
    DRINK_VERB => Drink_Action'Access,
    DROP_VERB => Drop_Action'Access,
    EAST_VERB => East_Action'Access,
    INVENTORY_VERB => Inventory_Action'Access,
    LOOK_VERB => Look_Action'Access,
    MAKE_VERB => Make_Action'Access,
    NORTH_VERB => North_Action'Access,
    READ_VERB => Read_Action'Access,
    SEARCH_VERB => Search_Action'Access,
    SOUTH_VERB => South_Action'Access,
    TAKE_VERB => Take_Action'Access,
    UNSUPPLIED => Unsupplied_Action'Access,
    UP_VERB => Up_Action'Access,
    WALK_VERB => Walk_Action'Access,
    WASH_VERB => Wash_Action'Access,
    WEST_VERB => West_Action'Access,
    WIPE_VERB => Wipe_Action'Access,
    others => Not_A_Verb_Action'Access
  );

  --
  --
  --
  procedure Test( Line : String ) is
    C : Command_Type;
  begin
    Put( ">>> " );
    Put_Line( Line );
    Parse( Line, C );
    Put( C );
    New_Line;
  end Test;

  --
  -- The command's parts are "bound".  Now execute the Command.
  --
  procedure Do_Command( C : Command_Type ) is
    Verb : Thing_Id;
    Action : Action_Ptr;
  begin
    Verb := C.Verb_Id;
    Action := Actions(Verb);
    Action( C );
  end Do_Command;

  Line : String(1..100);
  N : Natural;
  C : Command_Type;
begin
  Put_Line( "Begin" );
  Put( "There are " );
  Put( Words'Length, Width => 0 );
  Put_Line( " words in the dictionary." );
  -- Test( "" );
  -- Test( "look here" );
  -- Test( "look" );
  -- Test( "take kettle" );
  -- Test( "drop kettle" );
  -- Test( "too many words error" );
  Put_Line( "***" );

  Look_Here;
  loop
    exit when Is_Done;
    Put_Line( "---" );
    Put( "? " );
    Get_Line( Line, N );
    exit when N = 5 and Line(1..N) = "@quit";
    begin
      Parse( Line(1..N), C );
      delay 0.5;
      Do_Command( C );
    exception
      when Too_Many_Words =>
	    Put_Line( "Nope!  I'm a 2-word parser.  Try again." );
    end;
  end loop;

  Put_Line( "End" );
end coffee_maker;
