# Configuration guide — every knob, in plain language

This file explains **every setting in `R/config.R`**: what it does, what
values it accepts, and — most importantly — what happens when you turn it
one way versus the other. It is written for someone fairly new to biology
and to modeling, so it defines terms as it goes.

**You only ever edit `R/config.R`.** Everything the pipeline does is
controlled from that one file. The working code in `R/01_…` through
`R/06_…` reads your settings and never needs to be touched.

### The golden rule: turn one knob at a time

A species distribution model can look wildly optimistic or wildly bleak
depending purely on the settings you pick — not on anything about the
animal. If you change several knobs at once and the map changes, you have
no way to know *which* knob did it. So when you are exploring, **change a
single setting, re-run, and compare.** That habit is the whole point of
having a tidy config file.

### How to read each entry

Every knob below is laid out the same way:

- **What it is** — the plain-language meaning.
- **Default** — what the template ships with.
- **Options** — the values it accepts.
- **Which way to turn it** — what you gain and give up in each direction.

A quick vocabulary primer, used throughout:

- **Occurrence / presence** — a recorded sighting of the species (a dot on
  the map). We only have *sightings*; we almost never have confirmed
  reports of "the species is definitely NOT here."
- **Predictor** — a piece of environmental information (usually a climate
  measurement) the model uses to explain where the species lives.
- **Suitability** — the model's 0-to-1 score for how climatically suitable
  a place is. Higher = more like the places the species is found today.
- **Resolution** — the size of the map's pixels. "Finer" resolution =
  smaller pixels = more detail = bigger downloads and slower runs.

---

## 1. Which species, and its short name

```r
species_name  = "Lontra canadensis"
species_short = "river_otter"
```

**What it is.** `species_name` is the scientific (Latin) name of the
animal or plant you want to model. The pipeline sends this name to GBIF (a
giant global database of species sightings) to download the dots on the
map. `species_short` is just a nickname with no spaces — it gets used in
file names like `river_otter_model.rds`.

**Default.** The North American river otter (the Lewis & Clark mascot).

**Options.** Any scientific name GBIF recognizes. Spelling has to be close
— GBIF does a fuzzy match, but "close enough" still means close. Use the
*scientific* name, not the common name ("Lontra canadensis," not "river
otter"), because common names are ambiguous and vary by region.

**Which way to turn it.**
- To model a different species, change **both** lines: the scientific name
  and the nickname. That is usually the only edit you need to make.
- If you get far fewer dots than expected, check the spelling and try the
  name on [gbif.org](https://www.gbif.org) first. Some species are listed
  under an older name (a "synonym") and GBIF may or may not redirect.
- Pick a species with a decent number of records (hundreds to thousands).
  A species with only a handful of sightings can't support a reliable
  model — the map will look confident but mean very little.

---

## 2. The study region (map boundaries)

```r
extent        = c(xmin = -140, xmax = -100, ymin = 30, ymax = 62)
extent_pad_deg = 2
```

**What it is.** `extent` is the rectangle of the world you want to model,
given as edges in longitude (`xmin`/`xmax`, east–west) and latitude
(`ymin`/`ymax`, north–south). The default box covers western North
America. `extent_pad_deg` only matters if you set `extent = NULL` (see
below): it adds a margin of that many degrees around your sightings.

**Default.** Western North America — a good fit for a Pacific-Northwest
campus and a small, fast, class-friendly download.

**Options.**
- A box: four numbers as shown. Longitude runs from -180 to 180 (negative
  = the Americas); latitude from -90 to 90 (positive = north).
- `NULL`: let the pipeline draw the box automatically around wherever the
  species was actually seen, plus the `extent_pad_deg` margin.

**Which way to turn it.**
- **Bigger box** = you model more of the world. This is more honest if the
  species ranges widely (the otter actually lives across the whole
  continent), *but* it means a larger download and a slower run, and it
  can add lots of empty area the species never occupies. To model the
  otter's full range you might use `c(xmin = -165, xmax = -52, ymin = 25,
  ymax = 70)`.
- **Smaller box** = faster, smaller, easier to teach with — but if you
  crop too tight you cut off habitat that really exists, which makes the
  species look more restricted than it is.
- **A word of caution about future maps:** the box also limits where the
  model can show habitat *moving to*. If a warming climate would push a
  species north, but your box stops at the US–Canada border, the map
  simply can't show the northward shift. For future projections, give the
  species somewhere to go.
- **`NULL` (auto-box)** is convenient but tends to trace the shape of where
  people *looked*, not where the species could live — so a fixed,
  deliberate box is usually the better teaching choice.

---

## 3. Climate data resolution

```r
worldclim_res = "5"
```

**What it is.** How detailed the climate maps are, measured in
*arc-minutes* — a unit of pixel size. The number is roughly "how many
kilometers wide is one pixel," except smaller number = finer detail.

**Default.** `"5"` (about 9 km pixels) — a good balance for real work.

**Options.** `"10"`, `"5"`, `"2.5"`, `"0.5"` arc-minutes.
- `"10"` ≈ 18 km pixels — coarsest, fastest, smallest download.
- `"5"` ≈ 9 km pixels.
- `"2.5"` ≈ 4.5 km pixels.
- `"0.5"` ≈ 1 km pixels — finest, but a much larger download and slower.

**Which way to turn it.**
- **Coarser (`"10"`)**: use for teaching demos and quick tests. The
  download is small and the run is fast, so a whole class can do it. The
  map is blocky but the story is the same.
- **Finer (`"2.5"` or `"0.5"`)**: use for real analysis where local detail
  matters — mountains, coastlines, narrow valleys. The cost is download
  size (can be gigabytes at `"0.5"`) and runtime.
- The example figures shipped in `examples/` were made at `"10"` for speed;
  the template default is `"5"`. Finer resolution does **not** automatically
  mean a "better" or "more correct" model — it just means more spatial
  detail. If your sightings are only accurate to within a few kilometers,
  ultra-fine climate pixels add precision the data can't actually support.

---

## 4. Which climate variables to consider, and how aggressively to prune them

```r
bioclim_vars  = 1:19
cor_threshold = 0.7
```

**What it is.** WorldClim provides **19 standard climate variables** (called
"bioclim," bio1–bio19), all derived from temperature and rainfall — things
like average annual temperature, temperature of the coldest month, total
rainfall, rainfall in the driest quarter, and so on. `bioclim_vars` chooses
which of the 19 to *offer* the model. `cor_threshold` then automatically
*removes* variables that are near-duplicates of each other before the model
is fit.

**Why pruning exists.** Because all 19 come from the same raw data, many of
them move in lockstep — "average temperature" and "coldest-month
temperature" are often almost the same number in disguise. Feeding the
model several near-identical variables doesn't add knowledge; it muddies
the model's sense of *which* climate factor actually matters, and can make
it less stable. Pruning keeps one variable out of each near-identical
group and drops the rest.

**Default.** Consider all 19, then prune any pair that tracks each other
more than 70% (`0.7`). For the otter this left 8 distinct variables.

**Options.**
- `bioclim_vars`: any subset of `1:19`, e.g. `c(1, 5, 6, 12)` if you only
  want a few specific ones.
- `cor_threshold`: a number between 0 and 1 (the "how similar is too
  similar" cutoff).

**Which way to turn it.**
- **Lower `cor_threshold` (e.g. `0.5`)** = *more aggressive* pruning =
  fewer, more independent variables kept. Cleaner, more interpretable, less
  risk of the model over-relying on redundant inputs — but you might drop
  something biologically useful.
- **Higher `cor_threshold` (e.g. `0.9`, or effectively `1.0`)** = *little
  or no* pruning = the model sees almost all 19. This keeps every scrap of
  information, but the "which variable matters" report becomes muddy and
  the model can be less stable, especially when projected into future
  climate. (This is closer to what a MaxEnt-style workflow does, because
  MaxEnt has its own internal way of taming redundancy — the random forest
  used here does not, which is exactly why the template prunes up front.)
- **Hand-picking `bioclim_vars`** is worth it when you know the biology:
  if experts say your species is limited by winter cold and summer
  dryness, offering just those variables can beat throwing in all 19.

---

## 5. Sampling: background points, thinning, and the test split

```r
n_background  = 10000
thin_dist_km  = 5
test_fraction = 0.25
```

### `n_background` — how many "background" points

**What it is.** We have sightings (presences) but no confirmed absences.
So the model instead compares the sighting locations against a large sample
of *random* points from across the study area, called **background
points** — these describe "what the landscape looks like in general." The
model learns what makes the sighting spots *different* from the background.

**Default.** `10000`.

**Which way to turn it.**
- **More background points** = a more complete picture of the available
  landscape, at the cost of a slower run. For large study areas, more is
  generally better.
- **Fewer** = faster, but the background may not represent the whole region
  well. `10000` is a solid, common default; you rarely need to change it.
- Note: background points are **not** claims that the species is absent
  there — a background point can even land on a real sighting. They just
  characterize the environment on offer.

### `thin_dist_km` — spatial thinning distance

**What it is.** GBIF sightings pile up where *people* are — cities, roads,
popular parks. Left alone, the model can learn "where humans go birdwatching"
instead of "where the species lives." **Thinning** fixes this by keeping
only one sighting within any circle of this radius, spreading the dots out.

**Default.** `5` km.

**Which way to turn it.**
- **Larger distance (e.g. `10`, `25`)** = more aggressive thinning = fewer,
  more evenly spread points. Reduces the "where people go" bias more
  strongly, but throws away more data — bad if you already have few
  sightings.
- **Smaller distance (e.g. `1`)** = keeps more points, but leaves more of
  the crowding-near-cities bias in.
- A common rule of thumb is to match the thinning distance roughly to the
  climate resolution (points closer than one pixel add little anyway).

### `test_fraction` — how much data to hold back for grading

**What it is.** To grade itself honestly, the model sets aside a slice of
the data, trains on the rest, then checks how well it predicts the slice it
never saw. This is the "held-out test set."

**Default.** `0.25` (hold back 25%, train on 75%).

**Which way to turn it.**
- **Bigger test fraction** = a more stable grade (more test points), but
  the model trains on less data.
- **Smaller** = the model trains on more data, but the grade is based on
  fewer points and wobbles more.
- `0.2`–`0.3` is the usual range. Note this is the *random* split; see the
  next section for the more honest, spatially-aware grade.

---

## 6. Which model to fit

```r
method   = "rf"
rf_ntree = 1000
```

**What it is.** `method` chooses the modeling engine — the math that turns
"sightings + climate" into a suitability map. `rf_ntree` is a setting for
one of those engines (see below).

**Default.** `"rf"` — a down-sampled random forest.

**Options.**
- `"rf"` — **Random forest.** A powerful, general-purpose machine-learning
  method that builds many decision "trees" and averages them. Predicts
  very well and needs no special software. ("Down-sampled" just means it
  balances the sightings against the background so it isn't swamped.)
- `"glm"` — **Logistic regression.** A classic, simpler statistical model.
  More transparent and easier to explain, and its response curves are
  smooth and intuitive, but it can miss complicated patterns a forest
  catches.
- `"maxent"` — **MaxEnt.** The most widely published method in this field,
  purpose-built for presence-only data. **Requires Java** to be installed,
  which is why it is not the default here (Java setup is a common
  stumbling block on lab and cluster machines).

**Which way to turn it.**
- Start with **`"rf"`** — it works out of the box and predicts well.
- Switch to **`"glm"`** when you want maximum transparency for teaching, or
  a model whose behavior is easy to describe in words.
- Use **`"maxent"`** if you specifically want the field-standard method for
  a publication and you can get Java working. Be aware the different
  engines can extrapolate very differently into future climate — random
  forests tend to give gentler future changes, MaxEnt can show more
  dramatic declines — so the *method itself* is one of the knobs that
  changes how optimistic or bleak a future map looks.

**`rf_ntree`** — the number of trees in the random forest (only used when
`method = "rf"`).
- **More trees** = slightly more stable predictions, slower run. Gains
  flatten out; beyond ~1000 you rarely see a difference.
- **Fewer trees** = faster, marginally noisier. `1000` is a safe default;
  drop to `500` for quick tests.

---

## 7. Spatial cross-validation (the honest report card)

```r
run_spatial_cv    = TRUE
spatial_block_deg = 3
spatial_cv_k      = 5
```

**What it is.** The standard grade (from `test_fraction`) uses a *random*
split, where held-back points sit right next to training points — so the
model gets to "peek" at neighbors and its grade comes out flatteringly
high. **Spatial cross-validation** is a tougher, more honest test: it lays
a grid of large squares over the map, and hides *whole regions* at a time,
forcing the model to predict places genuinely unlike anything it trained
on. The resulting score is usually **lower** — and the gap between the two
is itself the lesson (it tells you how much the model was leaning on
geographic clustering).

**Default.** On, with 3-degree blocks and 5 folds.

**Options & which way to turn them.**
- **`run_spatial_cv`** — `TRUE` or `FALSE`. Turn it `FALSE` to skip this
  step entirely (a bit faster). Leave it `TRUE` to get the honest grade;
  it's a fantastic teaching contrast.
- **`spatial_block_deg`** — the size of each square block, in degrees
  (~3° ≈ 300 km). **Bigger blocks = a harder, more honest test**, because
  the hidden regions sit farther from the training data. Too big, though,
  and each fold hides so much that little is left to learn from. `3` is a
  reasonable middle.
- **`spatial_cv_k`** — how many groups the blocks are dealt into (the model
  is re-fit this many times, hiding one group each time). More folds =
  a smoother average grade but a longer run (it multiplies the model-fitting
  time). `5` is standard.

> **Runtime note:** because this step re-fits the model `spatial_cv_k`
> times, it roughly multiplies step 04's fitting time by that number. At
> coarse resolution that's seconds; at fine resolution with many trees it's
> worth knowing before you hit run.

---

## 8. Future climate projection

```r
future_gcm     = c("MPI-ESM1-2-HR", "MRI-ESM2-0", "EC-Earth3-Veg")
future_ssp     = "ssp245"
future_periods = c("2041-2060", "2081-2100")
```

The model is trained once on *today's* climate, then re-drawn onto
*future* climate to show where the species' climate niche is projected to
move. These three knobs describe which future.

### `future_ssp` — the emissions scenario ("how much warming?")

**What it is.** A storyline for how much greenhouse gas humanity emits this
century. This is often the **single most influential knob** for how bleak
or rosy the future map looks.

**Default.** `"ssp245"` — a moderate, middle-of-the-road scenario.

**Options.**
- `"ssp126"` — strong climate action; least warming.
- `"ssp245"` — moderate; a common "central" choice.
- `"ssp370"` — high emissions.
- `"ssp585"` — worst case, "kept burning everything"; most warming.

**Which way to turn it.** Higher numbers = more warming = usually more
dramatic range shifts and losses. Comparing `ssp126` to `ssp585` is like
comparing a best-case to a worst-case forecast — of *course* they differ.
If you want to show a range of possibilities, run the same species under
two scenarios and present them side by side (changing only this knob).

### `future_gcm` — which climate model(s) ("whose forecast?")

**What it is.** Different research centers build different global climate
models (GCMs). They agree on the big picture but disagree on details, and
some "run hotter" than others. You can give **one** model or a **list**.

**Default.** A list of three models — so the pipeline **averages** them
into an *ensemble* and also reports how many of them agree in each place.

**Which way to turn it.**
- **One model** = a single forecaster's opinion. Simpler, but you're at the
  mercy of that model's quirks — a hot-running model looks alarming, a
  mild one reassuring.
- **Several models (a list)** = a consensus. The average smooths out any
  one model's extremes, and the agreement map shows where the models are
  confident versus divided. **Recommended** — showing several models is far
  more honest than betting on one. WorldClim hosts about two dozen GCMs.

### `future_periods` — the time window ("how far ahead?")

**What it is.** Which 20-year future window(s) to map. You can give one or
several.

**Default.** `c("2041-2060", "2081-2100")` — mid-century and end-of-century.

**Options.** `"2021-2040"`, `"2041-2060"`, `"2061-2080"`, `"2081-2100"`.

**Which way to turn it.** Further-out windows show larger changes (climate
has drifted more). Listing two windows lets students see the *trajectory* —
how the range shifts step by step — rather than a single snapshot.

> **Apples-to-apples warning.** These three knobs are why two people can
> model "the same species" and reach opposite conclusions. If you compare
> your map to someone else's, check that the scenario, the model(s), *and*
> the time window all match before concluding the models disagree — most
> apparent disagreements are just different settings.

---

## 9. Map borders

```r
borders_state   = TRUE
borders_country = TRUE
borders_scale   = "50m"
```

**What it is.** Whether to draw administrative boundaries on the maps, so a
patch of suitable habitat can be read against the jurisdictions that manage
it (which states share a population, where a range crosses into Canada,
etc.). Boundary data is downloaded once from Natural Earth (public domain)
and cached; if the download fails, the maps still render, just without
borders.

**Defaults.** Both on, at `"50m"` detail.

**Options & which way to turn them.**
- **`borders_state`** / **`borders_country`** — `TRUE`/`FALSE`. Turn off
  for a cleaner, less busy map; leave on for context in a management or
  assessment setting.
- **`borders_scale`** — `"50m"` or `"10m"`. `"50m"` is plenty for regional
  maps. `"10m"` gives finer coastlines and boundaries (nice for small,
  zoomed-in areas) at the cost of a larger download.

---

## 10. Reproducibility and housekeeping

```r
seed      = 42
occ_limit = 8000
dir_raw   = "data/raw"
dir_proc  = "data/processed"
dir_fig   = "outputs/figures"
dir_mod   = "outputs/models"
```

### `seed` — the reproducibility anchor

**What it is.** Several steps use randomness (choosing background points,
splitting train/test, building the forest). A "seed" fixes that randomness
so **you get the exact same result every time you run** — essential for
teaching and for reproducible science.

**Which way to turn it.** Leave it fixed (any number works; `42` is
tradition). *Change* it deliberately if you want to check how much your
results wobble from run to run — re-running with several different seeds
and seeing similar maps is a good sign your model is stable.

### `occ_limit` — cap on how many sightings to download

**What it is.** The maximum number of GBIF records to pull. GBIF downloads
in pages of 300, so more records = a longer download.

**Which way to turn it.**
- **Higher** = more complete data for well-recorded species, slower
  download. (Thinning later removes crowding, so extra records aren't
  wasted.)
- **Lower** = faster, but you may under-sample a widespread species.
  `8000` is a practical classroom default.

### The `dir_*` paths

**What they are.** Where the pipeline writes its files: raw downloads,
processed data, figures, and model objects. **You normally never change
these** — they keep the project tidy and match what `.gitignore` expects.
Change them only if you have a specific reason to reorganize the folders.

---

## Quick reference: which knobs change the *science* vs. the *picture*

When a map surprises you, check these first:

**Change the actual result (the biology/statistics):**
`species_name`, `extent`, `worldclim_res`, `cor_threshold`, `method`,
`future_ssp`, `future_gcm`, `future_periods`, `thin_dist_km`.

**Mostly change speed, stability, or reproducibility (not the story):**
`n_background`, `test_fraction`, `rf_ntree`, `spatial_cv_k`, `seed`,
`occ_limit`.

**Change only how the map *looks*, not the numbers behind it:**
`borders_state`, `borders_country`, `borders_scale`, and (indirectly, by
zoom) `extent`.

And always, always: **turn one knob at a time.**
