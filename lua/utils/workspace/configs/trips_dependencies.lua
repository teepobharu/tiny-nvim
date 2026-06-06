require("utils.workspace.schema")

local workspace_root = require("utils.workspace.root")

local function root()
  return workspace_root.git_root()
end

---@type WorkspaceConfig
return {
  command = "WsTripsWebTripViewBffDependencyWorkspace",
  desc = "Open trips-web trip-view-bff cross-sell and saved dependency tabs",
  root = root,
  tabs = {
    {
      name = "ucs",
      specs = {
        -- DO NOT REMOVE: cross-sell usage in trip-view-bff.
        -- Alias: ucs = usage cross-sell. Focus: app usage sites before source library.
        { file = "apps/trip-view-bff/src/Clientside/package.json" },
        {
          first = {
            "apps/trip-view-bff/src/Clientside/src/trips/pages/triplist/components/MissingAnythingCrossSellWidget/MissingAnythingCrossSellWidget.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/triplist/components/MissingAnythingCrossSellWidget/index.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/triplist/components/MissingAnythingCrossSellWidget.tsx",
          },
        },
        {
          first = {
            "apps/trip-view-bff/src/Clientside/src/trips/pages/triplist/components/MissingAnythingCrossSellWidget/CrossSellItem.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/triplist/components/MissingAnythingCrossSellWidget/components/CrossSellItem.tsx",
          },
        },
        { file = "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/services/TripRecommendationRequest.ts" },
      },
    },
    {
      name = "cs",
      specs = {
        -- DO NOT REMOVE: original cross-sell library source.
        -- Alias: cs = cross-sell source. Focus: package, exported component, resolver, model, state, API.
        { file = "libs/cart/trip/package.json" },
        {
          first = {
            "libs/cart/trip/src/crossSellWidget/index.ts",
            "libs/cart/trip/src/crossSellWidget/component/index.ts",
            "libs/cart/trip/src/index.ts",
          },
        },
        { file = "libs/cart/trip/src/crossSellWidget/core/CrossSellResolver/crossSellCriteriaBuilder.ts" },
        { file = "libs/cart/trip/src/crossSellWidget/core/model/CrossSellCriteria.ts" },
        { file = "libs/cart/trip/src/crossSellWidget/core/model/CrossSellProductType.ts" },
        { file = "libs/cart/trip/src/crossSellWidget/core/store/features/features.reducer.ts" },
        { file = "libs/cart/trip/src/crossSellWidget/core/store/data/model/PropertyRecommendation.ts" },
        { file = "libs/cart/trip/src/api/restApi/restService.ts" },
      },
    },
    {
      name = "uns",
      specs = {
        -- DO NOT REMOVE: unified saved usage in trip-view-bff.
        -- Alias: uns = usage new/unified saved. Focus: app usage, gates, endpoint/store.
        { file = "apps/trip-view-bff/src/Clientside/package.json" },
        {
          first = {
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/SavedContentSection/SavedContentSection.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/SavedContentSection/index.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/SavedContentSection.tsx",
          },
        },
        {
          first = {
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/SavedStore/SavedStore.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/SavedStore/index.tsx",
            "apps/trip-view-bff/src/Clientside/src/trips/pages/tripdetail/components/SavedStore.tsx",
          },
        },
        { file = "apps/trip-view-bff/src/Clientside/src/trips/common/hooks/useSavedTabEnabled.ts" },
        { file = "apps/trip-view-bff/src/Clientside/src/trips/stores/endpoint/getTripDetailEndpoint.ts" },
        { file = "apps/trip-view-bff/src/Clientside/src/trips/stores/tripdetail/tripDetailStore.ts" },
      },
    },
    {
      name = "saved",
      specs = {
        -- DO NOT REMOVE: original saved libraries and API clients.
        -- Alias: saved. Focus: package files first, exported component/config/state/API calls.
        { file = "libs/trips/saved-v2/package.json" },
        { file = "libs/trips/saved/package.json" },
        {
          first = {
            "libs/trips/saved-v2/src/index.ts",
            "libs/trips/saved-v2/src/SavedContent.tsx",
            "libs/trips/saved-v2/src/components/SavedContent.tsx",
          },
        },
        {
          first = {
            "libs/trips/saved/src/index.ts",
            "libs/trips/saved/src/savedAPI/index.ts",
          },
        },
        {
          first = {
            "libs/trips/api-clients/src/api/cartGateway/index.ts",
            "libs/trips/api-clients/src/api/cartGateway/generated/index.ts",
          },
        },
        {
          first = {
            "apps/cart/cart-gateway/Agoda.Cronos.CartGateway.Api/Controllers/SavedApiController.cs",
            "apps/cart/shared/Agoda.Cronos.CartGateway.Core/Models/Saved/Add/AddSavedRequestViewModel.cs",
          },
        },
      },
    },
  },
}

