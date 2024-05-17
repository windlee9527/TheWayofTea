# https://github.com/mulungood/gororobas/blob/ce3b0f1621f86034efb3cf534a20391efc5c5a42/edgedb/default.esdl
using extension auth;

module default {
  # QUESTIONS:
  # 1. How do Enums evolve over time? Postgres doesn't allow modifying them
  #   ✨ EdgeDB win #1: enums can be easily modified
  # 2. How does removing an Enum option work?
  #   💩 EdgeDB failure #1: the schema migration doesn't handle that, and so they can't be applied if invalid values are found
  #   ❓ Caveat: Perhaps there's a way to handle this in the schema migration?
  # 3. Should I include public user data in the User type, or move it to a separate one that is linked to it?
  #   Data includes: name, location, photo
  # 
  # DECISIONS:
  # 1. I'll keep storing images in Sanity (good CDN, good pricing, familiar API)
  
  scalar type Role extending enum<ADMIN,USER,MODERATOR>;
  scalar type SourceType extending enum<GOROROBAS,EXTERNAL>;
  scalar type Gender extending enum<FEMININO,MASCULINO,NEUTRO>;
  scalar type VegetableUsage extending enum<ALIMENTO_ANIMAL,ALIMENTO_HUMANO,CONSTRUCAO,MATERIA_ORGANICA,MEDICINAL,COSMETICO,ORNAMENTAL,RITUALISTICO>;
  scalar type EdiblePart extending enum<FRUTO,FLOR,FOLHA,CAULE,SEMENTE,CASCA,BULBO,BROTO,RAIZ,TUBERCULO,RIZOMA>;
  scalar type VegetableLifeCycle extending enum<SEMESTRAL,ANUAL,BIENAL,PERENE>;
  scalar type Stratum extending enum<EMERGENTE,ALTO,MEDIO,BAIXO,RASTEIRO>;
  scalar type PlantingMethod extending enum<BROTO,ENXERTO,ESTACA,RIZOMA,SEMENTE,TUBERCULO>;
  scalar type TipSubject extending enum<PLANTIO,CRESCIMENTO,COLHEITA>;
  scalar type VegetableWishlistStatus extending enum<QUERO_CULTIVAR,SEM_INTERESSE,JA_CULTIVEI,ESTOU_CULTIVANDO>;

  global current_user := (
    assert_single((
      select User
      filter .identity = global ext::auth::ClientTokenIdentity
    ))
  );

  global current_user_profile := (
    assert_single((
      select UserProfile
      filter .user = global current_user
    ))
  );

  abstract type UserCanInsert {
    access policy authenticated_user_can_insert
      allow insert
      using (exists global current_user);
  }

  abstract type AdminCanDoAnything {
    access policy admin_can_do_anything
      allow all
      using (global current_user.userRole ?= Role.ADMIN);
  }

  type User extending AdminCanDoAnything {
    required identity: ext::auth::Identity {
      constraint exclusive;
    };
    email: str {
      constraint exclusive;
    };
  
    userRole: Role {
      default := "USER";
    };

    created: datetime {
      rewrite insert using (datetime_of_statement());
    }
    updated: datetime {
      rewrite insert using (datetime_of_statement());
      rewrite update using (datetime_of_statement());
    }

    access policy owner_can_select_or_delete
      allow select, delete
      using (global current_user.identity ?= .identity);
  }

  scalar type HistoryAction extending enum<`INSERT`, `UPDATE`, `DELETE`>;
  type HistoryLog {
    required action: HistoryAction;
    timestamp: datetime {
      default := datetime_current();
      readonly := true;
    };
    performed_by: UserProfile {
      on target delete allow;
    };;
    old: json;
    new: json;
    target: Auditable {
      on target delete allow;
    };
  }

  abstract type Auditable {
    created_at: datetime {
      default := datetime_of_transaction();
      readonly := true;
    };
    updated_at: datetime {
      rewrite insert, update using (datetime_of_statement());
    };
    created_by: UserProfile {
      # @TODO can we do this only when there is no explicit value assigned? Alternatively, can we impersonate a user when setting an auditable item as an admin?
      rewrite insert using (global current_user_profile);
      on target delete allow;
    };

    trigger log_insert after insert for each do (
      insert HistoryLog {
        action := HistoryAction.`INSERT`,
        target := __new__,
        performed_by := global current_user_profile,
        new := <json>__new__
      }
    );

    trigger log_update after update for each do (
      insert HistoryLog {
        action := HistoryAction.`UPDATE`,
        target := __new__,
        performed_by := global current_user_profile,
        old := <json>__old__,
        new := <json>__new__,
      }
    );

    trigger log_delete after delete for each do (
      insert HistoryLog {
        action := HistoryAction.`DELETE`,
        target := __old__,
        performed_by := global current_user_profile,
        old := <json>__old__
      }
    );
  }

  abstract type WithSource {
    sourceType: SourceType;
    credits: str;
    source: str;
    multi users: UserProfile {
      on target delete allow;
    };
  }

  abstract type PublicRead {
    access policy public_read_only
      allow select;
  }

  abstract type WithHandle {
    required handle: str {
      annotation title := 'An unique (per-type) URL-friendly handle';
      
      # Can't be modified after creation for URL integrity
      # @TODO can we have a `past_handles` array that keeps track of previous handles automatically?
      # readonly := true;

      # exclusive among the current object type
      delegated constraint exclusive;

      constraint min_len_value(2);
      # slugs-can-only-contain-numbers-letters-and-dashes
      constraint regexp(r'^[a-z0-9-]+$');
    };
  }

  type Image extending WithSource, PublicRead, Auditable, AdminCanDoAnything {
    required sanity_id: str {
      constraint exclusive;
    };
    label: str;
    # Sanity-compliant values
    hotspot: json;
    crop: json;
  }

  type UserProfile extending WithHandle, PublicRead {
    required user: User {
      constraint exclusive;

      on target delete delete source;
    };
    required name: str;
    bio: str;
    location: str;
    photo: Image;

    access policy owner_has_full_access
      allow all
      using (global current_user ?= .user);
  }

  type VegetableVariety extending WithHandle, PublicRead, Auditable, UserCanInsert, AdminCanDoAnything {
    required names: array<str>;
    multi photos: Image {
      order_index: int16;
    };
  }

  type VegetableTip extending WithHandle, WithSource, PublicRead, Auditable, AdminCanDoAnything {
    required multi subjects: TipSubject;
    required content: json;

    multi content_links: WithHandle {
      # Let dangling links live
      on target delete allow;
    };
  }

  type Vegetable extending WithHandle, PublicRead, Auditable, UserCanInsert, AdminCanDoAnything {
    required names: array<str>;
    scientific_names: array<str>;
    strata: array<Stratum>;
    gender: Gender;
    planting_methods: array<PlantingMethod>;
    edible_parts: array<EdiblePart>;
    lifecycles: array<VegetableLifeCycle>;
    uses: array<VegetableUsage>;
    origin: str;
    height_min: float32;
    height_max: float32;
    temperature_min: float32;
    temperature_max: float32;
    content: json;

    multi photos: Image {
      order_index: int16;
    };

    multi varieties: VegetableVariety {
      constraint exclusive;
      order_index: int16;
      
      on target delete allow;
      # When a vegetable is deleted, delete all of its varieties
      on source delete delete target;
    };

    multi tips: VegetableTip {
      constraint exclusive;
      order_index: int16;
      
      on target delete allow;
      # When a vegetable is deleted, delete all of its tips
      on source delete delete target;
    };

    # Computed
    multi friends := (
      with parent_id := .id
      select .<vegetables[is VegetableFriendship].vegetables
      filter .id != parent_id
    );
    multi wishlisted_by := (
      with parent_id := .id
      select .<vegetable[is UserWishlist]
          filter .status != <VegetableWishlistStatus>'SEM_INTERESSE'
    );
  }

  type VegetableFriendship extending Auditable, PublicRead, AdminCanDoAnything {
    required multi vegetables: Vegetable {
      # Can't modify a friendship after it's created
      readonly := true;
      
      on target delete delete source;
    };
    required unique_key: str {
      readonly := true;
    };

    constraint exclusive on (.unique_key);
  }

  type UserWishlist extending AdminCanDoAnything {
    required user_profile: UserProfile {
      on target delete delete source;
    };
    required vegetable: Vegetable {
      on target delete delete source;
    };
    required status: VegetableWishlistStatus;

    constraint exclusive on ((.user_profile, .vegetable));
    
    access policy owner_can_do_anything
      allow all
      using (global current_user_profile ?= .user_profile);
  }
}