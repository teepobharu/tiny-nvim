require("utils.workspace.schema")

local workspace_root = require("utils.workspace.root")

local function root()
  return workspace_root.git_root()
end

---@type WorkspaceConfig
return {
  command = "WsTripsWebTripViewBffWorkspace",
  desc = "Open trips-web trip-view-bff package, server, detail, and list tabs",
  root = root,
  tabs = {
    {
      name = "deps",
      specs = {
        -- DO NOT REMOVE: trip-view-bff app dependency entrypoints. No tests/storybook here.
        -- Alias: deps. Focus: package metadata + install/build scripts for active client app.
        { file = "apps/trip-view-bff/src/Clientside/package.json" },
        { grep = "apps/trip-view-bff/**/package.json", max_depth = 4, max = 3 },
      },
    },
    {
      name = "sv",
      specs = {
        -- DO NOT REMOVE: server-side request flow for trip list/detail.
        -- Alias: sv. Focus: MVC controllers, API controllers, handlers, services.
        { file = "apps/trip-view-bff/src/Serverside/Agoda.Cronos.Mmb/Controllers/TripDetailController.cs" },
        { file = "apps/trip-view-bff/src/Serverside/Agoda.Cronos.Mmb/Controllers/TripListController.cs" },
        { file = "apps/trip-view-bff/src/Serverside/Agoda.Cronos.Mmb.All/Controllers/TripDetailApiController.cs" },
        { file = "apps/trip-view-bff/src/Serverside/Agoda.Cronos.Mmb.All/Controllers/TripListApiController.cs" },
        { file = "apps/trip-view-bff/src/Serverside/Agoda.Cronos.Mmb.All/Handlers/TripDetailHandler.cs" },
        { file = "apps/trip-view-bff/src/Serverside/Agoda.Cronos.Mmb.All/Handlers/TripListHandler.cs" },
        { file = "apps/trip-view-bff/src/Serverside/Agoda.Cronos.Mmb.All/Services/TripDetailService.cs" },
        { file = "apps/trip-view-bff/src/Serverside/Agoda.Cronos.Mmb.All/Services/TripListService.cs" },
        { file = "apps/trip-view-bff/src/Serverside/Agoda.Cronos.Mmb.All/Mappers/TripDetailMapper.cs" },
        { file = "apps/trip-view-bff/src/Serverside/Agoda.Cronos.Mmb.All/Mappers/TripListMapper.cs" },
      },
    },
    {
      name = "detail",
      specs = {
        -- DO NOT REMOVE: client-side trip detail workspace.
        -- Alias: detail. Focus: page/container, main card/date timeline, store, API endpoint.
        -- Entry files are explicit or first-existing candidates to avoid slow globs.
        {
          first = {
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/index.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/index.ts",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/TripDetailPage.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/TripDetailPage.ts",
          },
        },
        {
          first = {
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/TripDetailContainer/TripDetailContainer.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/TripDetailContainer/index.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/TripDetailContainer.tsx",
          },
        },
        {
          first = {
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/TripContainer/TripContainer.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/TripContainer/index.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/TripContainer.tsx",
          },
        },
        {
          first = {
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/TripMainCard/TripMainCard.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/TripMainCard/index.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/TripMainCard.tsx",
          },
        },
        {
          first = {
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/TripTimeline/TripTimeline.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/TripTimeline/index.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/TripTimeline.tsx",
          },
        },
        {
          first = {
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/TripTimeline/DateCard.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/DateCard/DateCard.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/DateCard.tsx",
          },
        },
        { file = "apps/trip-view-bff/src/Clientside/src/trips/stores/tripdetail/tripDetailStore.ts" },
        { file = "apps/trip-view-bff/src/Clientside/src/trips/stores/endpoint/getTripDetailEndpoint.ts" },
        { file = "apps/trip-view-bff/src/Clientside/src/trips/stores/tripdetail/slice/tripDetailRawDataSlice.ts" },
        { file = "apps/trip-view-bff/src/Clientside/src/trips/stores/tripdetail/slice/tripDetailPageSlice.ts" },
      },
    },
    {
      name = "list",
      specs = {
        -- DO NOT REMOVE: client-side trip list workspace.
        -- Alias: list. Focus: page/container, list section, shared card, store, API endpoint.
        -- Entry files are explicit or first-existing candidates to avoid slow globs.
        {
          first = {
            "apps/trip-view-bff/src/Clientside/src/trips/pages/triplist/index.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/triplist/index.ts",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/triplist/TripListPage.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/triplist/TripListPage.ts",
          },
        },
        {
          first = {
            "apps/trip-view-bff/src/Clientside/src/trips/pages/triplist/components/TripListContainer/TripListContainer.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/triplist/components/TripListContainer/index.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/triplist/components/TripListContainer.tsx",
          },
        },
        {
          first = {
            "apps/trip-view-bff/src/Clientside/src/trips/pages/triplist/components/TripListSection/TripListSection.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/triplist/components/TripListSection/index.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/triplist/components/TripListSection.tsx",
          },
        },
        {
          first = {
            "apps/trip-view-bff/src/Clientside/src/trips/common/components/TripCard/TripCard.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/common/components/TripCard/index.tsx",
            "libs/trips/shared-components/src/components/TripCard/TripCard.tsx",
            "libs/trips/shared-components/src/components/TripCard/index.tsx",
          },
        },
        { file = "apps/trip-view-bff/src/Clientside/src/trips/common/utils/tripCardMapper.ts" },
        { file = "apps/trip-view-bff/src/Clientside/src/trips/stores/triplist/tripListStore.ts" },
        { file = "apps/trip-view-bff/src/Clientside/src/trips/stores/triplist/selectors/tripListSection.selectors.ts" },
        { file = "apps/trip-view-bff/src/Clientside/src/trips/stores/triplist/selectors/tripListCompletedSection.selectors.ts" },
        { file = "apps/trip-view-bff/src/Clientside/src/trips/stores/endpoint/getTripListEndpoint.ts" },
      },
    },
  },
}

