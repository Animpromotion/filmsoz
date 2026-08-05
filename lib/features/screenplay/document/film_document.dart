import 'package:filmsoz_studio/features/screenplay/creative/creative_material.dart';
import 'package:filmsoz_studio/features/screenplay/development/scene_development.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_block.dart';
import 'package:filmsoz_studio/features/screenplay/document/scene_section.dart';
import 'package:filmsoz_studio/features/screenplay/production/production_planning.dart';
import 'package:filmsoz_studio/features/screenplay/postproduction/postproduction.dart';
import 'package:filmsoz_studio/features/screenplay/management/production_management.dart';
import 'package:filmsoz_studio/features/screenplay/shooting_control/shooting_control.dart';
import 'package:filmsoz_studio/features/screenplay/storyboard/storyboard_shot.dart';
import 'package:filmsoz_studio/features/screenplay/versioning/project_versioning.dart';

class FilmDocument {
  FilmDocument({
    required this.blocks,
    Map<String, String>? sceneNotes,
    Map<String, SceneDevelopmentData>? sceneDevelopment,
    Map<String, SceneProductionData>? sceneProduction,
    List<ShootingDayPlan>? shootingDays,
    List<ProductionPerson>? productionPeople,
    List<BudgetItem>? budgetItems,
    Map<String, List<StoryboardShot>>? storyboardShots,
    Map<String, List<ShotTake>>? shotTakes,
    Map<String, ShootingDayJournal>? shootingDayJournals,
    Map<String, ScenePostProductionData>? scenePostProduction,
    List<PostProductionSequence>? postProductionSequences,
    List<EditVersion>? editVersions,
    List<PostProductionTask>? postProductionTasks,
    List<MissingMaterialItem>? missingMaterials,
    List<ProjectMember>? projectMembers,
    List<CollaborationComment>? collaborationComments,
    List<ProjectChangeEntry>? projectChangeLog,
    List<ProjectCheckpoint>? projectCheckpoints,
    List<CreativeMaterial>? creativeMaterials,
    ProjectVersioningSettings? versioningSettings,
    String budgetCurrency = 'TJS',
    ScreenplayGoals? goals,
  })  : sceneNotes =
            Map<String, String>.of(sceneNotes ?? const <String, String>{}),
        sceneDevelopment = Map<String, SceneDevelopmentData>.of(
          sceneDevelopment ?? const <String, SceneDevelopmentData>{},
        ),
        sceneProduction = Map<String, SceneProductionData>.of(
          sceneProduction ?? const <String, SceneProductionData>{},
        ),
        shootingDays = List<ShootingDayPlan>.of(
          shootingDays ?? const <ShootingDayPlan>[],
        ),
        productionPeople = List<ProductionPerson>.of(
          productionPeople ?? const <ProductionPerson>[],
        ),
        budgetItems = List<BudgetItem>.of(
          budgetItems ?? const <BudgetItem>[],
        ),
        storyboardShots = <String, List<StoryboardShot>>{
          for (final entry
              in (storyboardShots ?? const <String, List<StoryboardShot>>{})
                  .entries)
            entry.key: List<StoryboardShot>.of(entry.value),
        },
        shotTakes = <String, List<ShotTake>>{
          for (final entry
              in (shotTakes ?? const <String, List<ShotTake>>{}).entries)
            entry.key: List<ShotTake>.of(entry.value),
        },
        shootingDayJournals = Map<String, ShootingDayJournal>.of(
          shootingDayJournals ?? const <String, ShootingDayJournal>{},
        ),
        scenePostProduction = Map<String, ScenePostProductionData>.of(
          scenePostProduction ?? const <String, ScenePostProductionData>{},
        ),
        postProductionSequences = List<PostProductionSequence>.of(
          postProductionSequences ?? const <PostProductionSequence>[],
        ),
        editVersions = List<EditVersion>.of(
          editVersions ?? const <EditVersion>[],
        ),
        postProductionTasks = List<PostProductionTask>.of(
          postProductionTasks ?? const <PostProductionTask>[],
        ),
        missingMaterials = List<MissingMaterialItem>.of(
          missingMaterials ?? const <MissingMaterialItem>[],
        ),
        projectMembers = List<ProjectMember>.of(
          projectMembers ?? const <ProjectMember>[],
        ),
        collaborationComments = List<CollaborationComment>.of(
          collaborationComments ?? const <CollaborationComment>[],
        ),
        projectChangeLog = List<ProjectChangeEntry>.of(
          projectChangeLog ?? const <ProjectChangeEntry>[],
        ),
        projectCheckpoints = List<ProjectCheckpoint>.of(
          projectCheckpoints ?? const <ProjectCheckpoint>[],
        ),
        creativeMaterials = List<CreativeMaterial>.of(
          creativeMaterials ?? const <CreativeMaterial>[],
        ),
        versioningSettings =
            versioningSettings ?? const ProjectVersioningSettings(),
        budgetCurrency = budgetCurrency.trim().isEmpty
            ? 'TJS'
            : budgetCurrency.trim().toUpperCase(),
        goals = goals ?? const ScreenplayGoals();

  final List<FilmBlock> blocks;
  final Map<String, String> sceneNotes;
  final Map<String, SceneDevelopmentData> sceneDevelopment;
  final Map<String, SceneProductionData> sceneProduction;
  final List<ShootingDayPlan> shootingDays;
  final List<ProductionPerson> productionPeople;
  final List<BudgetItem> budgetItems;
  final Map<String, List<StoryboardShot>> storyboardShots;
  final Map<String, List<ShotTake>> shotTakes;
  final Map<String, ShootingDayJournal> shootingDayJournals;
  final Map<String, ScenePostProductionData> scenePostProduction;
  final List<PostProductionSequence> postProductionSequences;
  final List<EditVersion> editVersions;
  final List<PostProductionTask> postProductionTasks;
  final List<MissingMaterialItem> missingMaterials;
  final List<ProjectMember> projectMembers;
  final List<CollaborationComment> collaborationComments;
  final List<ProjectChangeEntry> projectChangeLog;
  final List<ProjectCheckpoint> projectCheckpoints;
  final List<CreativeMaterial> creativeMaterials;
  ProjectVersioningSettings versioningSettings;
  String budgetCurrency;
  ScreenplayGoals goals;

  factory FilmDocument.empty() {
    return FilmDocument(
      blocks: <FilmBlock>[
        FilmBlock(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          type: BlockType.sceneHeading,
          text: 'ИНТ. СТУДИЯ - ДЕНЬ',
        ),
      ],
    );
  }

  List<SceneSection> get sceneSections {
    final headingIndexes = <int>[];

    for (var index = 0; index < blocks.length; index++) {
      if (blocks[index].type == BlockType.sceneHeading) {
        headingIndexes.add(index);
      }
    }

    final sections = <SceneSection>[];

    for (var sceneIndex = 0; sceneIndex < headingIndexes.length; sceneIndex++) {
      final startIndex = headingIndexes[sceneIndex];
      final endIndexExclusive = sceneIndex + 1 < headingIndexes.length
          ? headingIndexes[sceneIndex + 1]
          : blocks.length;
      final sceneBlocks =
          blocks.sublist(startIndex, endIndexExclusive).toList(growable: false);

      sections.add(
        SceneSection(
          number: sceneIndex + 1,
          startIndex: startIndex,
          endIndexExclusive: endIndexExclusive,
          heading: sceneBlocks.first,
          blocks: sceneBlocks,
        ),
      );
    }

    return sections;
  }

  List<FilmBlock> get scenes {
    return sceneSections
        .map((section) => section.heading)
        .toList(growable: false);
  }

  SceneSection? sceneById(String sceneId) {
    for (final scene in sceneSections) {
      if (scene.id == sceneId) {
        return scene;
      }
    }

    return null;
  }

  String sceneNote(String sceneId) => sceneNotes[sceneId] ?? '';

  SceneDevelopmentData sceneDevelopmentFor(String sceneId) {
    return sceneDevelopment[sceneId] ?? const SceneDevelopmentData();
  }

  SceneProductionData sceneProductionFor(String sceneId) {
    return sceneProduction[sceneId] ?? const SceneProductionData();
  }

  ProductionPerson? productionPersonById(String personId) {
    for (final person in productionPeople) {
      if (person.id == personId) {
        return person;
      }
    }

    return null;
  }

  BudgetItem? budgetItemById(String itemId) {
    for (final item in budgetItems) {
      if (item.id == itemId) {
        return item;
      }
    }

    return null;
  }

  List<StoryboardShot> storyboardShotsFor(String sceneId) {
    return List<StoryboardShot>.unmodifiable(
      storyboardShots[sceneId] ?? const <StoryboardShot>[],
    );
  }

  StoryboardShot? storyboardShotById(String sceneId, String shotId) {
    final shots = storyboardShots[sceneId];

    if (shots == null) {
      return null;
    }

    for (final shot in shots) {
      if (shot.id == shotId) {
        return shot;
      }
    }

    return null;
  }

  List<ShotTake> shotTakesFor(String shotId) {
    return List<ShotTake>.unmodifiable(
      shotTakes[shotId] ?? const <ShotTake>[],
    );
  }

  ShotTake? shotTakeById(String shotId, String takeId) {
    final takes = shotTakes[shotId];

    if (takes == null) {
      return null;
    }

    for (final take in takes) {
      if (take.id == takeId) {
        return take;
      }
    }

    return null;
  }

  ShootingDayJournal shootingDayJournalFor(String dayId) {
    return shootingDayJournals[dayId] ?? const ShootingDayJournal();
  }

  ScenePostProductionData scenePostProductionFor(String sceneId) {
    return scenePostProduction[sceneId] ?? const ScenePostProductionData();
  }

  PostProductionSequence? postProductionSequenceById(String sequenceId) {
    for (final sequence in postProductionSequences) {
      if (sequence.id == sequenceId) {
        return sequence;
      }
    }

    return null;
  }

  EditVersion? editVersionById(String versionId) {
    for (final version in editVersions) {
      if (version.id == versionId) {
        return version;
      }
    }

    return null;
  }

  PostProductionTask? postProductionTaskById(String taskId) {
    for (final task in postProductionTasks) {
      if (task.id == taskId) {
        return task;
      }
    }

    return null;
  }

  MissingMaterialItem? missingMaterialById(String itemId) {
    for (final item in missingMaterials) {
      if (item.id == itemId) {
        return item;
      }
    }

    return null;
  }

  ProjectMember? projectMemberById(String memberId) {
    for (final member in projectMembers) {
      if (member.id == memberId) {
        return member;
      }
    }

    return null;
  }

  CollaborationComment? collaborationCommentById(String commentId) {
    for (final comment in collaborationComments) {
      if (comment.id == commentId) {
        return comment;
      }
    }

    return null;
  }

  ProjectCheckpoint? projectCheckpointById(String checkpointId) {
    for (final checkpoint in projectCheckpoints) {
      if (checkpoint.id == checkpointId) {
        return checkpoint;
      }
    }

    return null;
  }

  CreativeMaterial? creativeMaterialById(String materialId) {
    for (final material in creativeMaterials) {
      if (material.id == materialId) {
        return material;
      }
    }

    return null;
  }

  ShootingDayPlan? shootingDayById(String dayId) {
    for (final day in shootingDays) {
      if (day.id == dayId) {
        return day;
      }
    }

    return null;
  }

  Map<String, dynamic> toJson({bool includeCheckpoints = true}) {
    return <String, dynamic>{
      'blocks': blocks.map((block) => block.toJson()).toList(growable: false),
      'sceneNotes': Map<String, String>.of(sceneNotes),
      'sceneDevelopment': sceneDevelopment.map(
        (sceneId, data) => MapEntry(sceneId, data.toJson()),
      ),
      'sceneProduction': sceneProduction.map(
        (sceneId, data) => MapEntry(sceneId, data.toJson()),
      ),
      'shootingDays':
          shootingDays.map((day) => day.toJson()).toList(growable: false),
      'productionPeople': productionPeople
          .map((person) => person.toJson())
          .toList(growable: false),
      'budgetItems':
          budgetItems.map((item) => item.toJson()).toList(growable: false),
      'storyboardShots': storyboardShots.map(
        (sceneId, shots) => MapEntry(
          sceneId,
          shots.map((shot) => shot.toJson()).toList(growable: false),
        ),
      ),
      'shotTakes': shotTakes.map(
        (shotId, takes) => MapEntry(
          shotId,
          takes.map((take) => take.toJson()).toList(growable: false),
        ),
      ),
      'shootingDayJournals': shootingDayJournals.map(
        (dayId, journal) => MapEntry(dayId, journal.toJson()),
      ),
      'scenePostProduction': scenePostProduction.map(
        (sceneId, data) => MapEntry(sceneId, data.toJson()),
      ),
      'postProductionSequences': postProductionSequences
          .map((sequence) => sequence.toJson())
          .toList(growable: false),
      'editVersions': editVersions
          .map((version) => version.toJson())
          .toList(growable: false),
      'postProductionTasks': postProductionTasks
          .map((task) => task.toJson())
          .toList(growable: false),
      'missingMaterials':
          missingMaterials.map((item) => item.toJson()).toList(growable: false),
      'projectMembers': projectMembers
          .map((member) => member.toJson())
          .toList(growable: false),
      'collaborationComments': collaborationComments
          .map((comment) => comment.toJson())
          .toList(growable: false),
      'projectChangeLog': projectChangeLog
          .map((entry) => entry.toJson())
          .toList(growable: false),
      if (includeCheckpoints)
        'projectCheckpoints': projectCheckpoints
            .map((checkpoint) => checkpoint.toJson())
            .toList(growable: false),
      'creativeMaterials': creativeMaterials
          .map((material) => material.toJson())
          .toList(growable: false),
      'versioningSettings': versioningSettings.toJson(),
      'budgetCurrency': budgetCurrency,
      'goals': goals.toJson(),
    };
  }

  factory FilmDocument.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'];

    if (rawBlocks is! List) {
      return FilmDocument.empty();
    }

    final blocks = <FilmBlock>[];

    for (final rawBlock in rawBlocks) {
      if (rawBlock is Map<String, dynamic>) {
        blocks.add(FilmBlock.fromJson(rawBlock));
      } else if (rawBlock is Map) {
        blocks.add(
          FilmBlock.fromJson(
            rawBlock.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      }
    }

    if (blocks.isEmpty) {
      return FilmDocument.empty();
    }

    final notes = <String, String>{};
    final rawNotes = json['sceneNotes'];

    if (rawNotes is Map) {
      for (final entry in rawNotes.entries) {
        final key = entry.key.toString();
        final value = entry.value?.toString() ?? '';

        if (key.isNotEmpty && value.trim().isNotEmpty) {
          notes[key] = value;
        }
      }
    }

    final development = <String, SceneDevelopmentData>{};
    final rawDevelopment = json['sceneDevelopment'];

    if (rawDevelopment is Map) {
      for (final entry in rawDevelopment.entries) {
        final sceneId = entry.key.toString();
        final rawData = entry.value;

        if (sceneId.isEmpty || rawData is! Map) {
          continue;
        }

        final data = SceneDevelopmentData.fromJson(
          rawData.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );

        if (!data.isDefault) {
          development[sceneId] = data;
        }
      }
    }

    final production = <String, SceneProductionData>{};
    final rawProduction = json['sceneProduction'];

    if (rawProduction is Map) {
      for (final entry in rawProduction.entries) {
        final sceneId = entry.key.toString();
        final rawData = entry.value;

        if (sceneId.isEmpty || rawData is! Map) {
          continue;
        }

        final data = SceneProductionData.fromJson(
          rawData.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );

        if (!data.isDefault) {
          production[sceneId] = data;
        }
      }
    }

    final shootingDays = <ShootingDayPlan>[];
    final rawShootingDays = json['shootingDays'];

    if (rawShootingDays is List) {
      for (final rawDay in rawShootingDays) {
        if (rawDay is! Map) {
          continue;
        }

        shootingDays.add(
          ShootingDayPlan.fromJson(
            rawDay.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      }
    }

    final productionPeople = <ProductionPerson>[];
    final rawProductionPeople = json['productionPeople'];

    if (rawProductionPeople is List) {
      for (final rawPerson in rawProductionPeople) {
        if (rawPerson is! Map) {
          continue;
        }

        productionPeople.add(
          ProductionPerson.fromJson(
            rawPerson.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      }
    }

    final budgetItems = <BudgetItem>[];
    final rawBudgetItems = json['budgetItems'];

    if (rawBudgetItems is List) {
      for (final rawItem in rawBudgetItems) {
        if (rawItem is! Map) {
          continue;
        }

        budgetItems.add(
          BudgetItem.fromJson(
            rawItem.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      }
    }

    final storyboardShots = <String, List<StoryboardShot>>{};
    final rawStoryboardShots = json['storyboardShots'];

    if (rawStoryboardShots is Map) {
      for (final entry in rawStoryboardShots.entries) {
        final sceneId = entry.key.toString();
        final rawShots = entry.value;

        if (sceneId.isEmpty || rawShots is! List) {
          continue;
        }

        final shots = <StoryboardShot>[];

        for (final rawShot in rawShots) {
          if (rawShot is! Map) {
            continue;
          }

          shots.add(
            StoryboardShot.fromJson(
              rawShot.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            ),
          );
        }

        if (shots.isNotEmpty) {
          storyboardShots[sceneId] = shots;
        }
      }
    }

    final shotTakes = <String, List<ShotTake>>{};
    final rawShotTakes = json['shotTakes'];

    if (rawShotTakes is Map) {
      for (final entry in rawShotTakes.entries) {
        final shotId = entry.key.toString();
        final rawTakes = entry.value;

        if (shotId.isEmpty || rawTakes is! List) {
          continue;
        }

        final takes = <ShotTake>[];

        for (final rawTake in rawTakes) {
          if (rawTake is! Map) {
            continue;
          }

          takes.add(
            ShotTake.fromJson(
              rawTake.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            ),
          );
        }

        if (takes.isNotEmpty) {
          shotTakes[shotId] = takes;
        }
      }
    }

    final shootingDayJournals = <String, ShootingDayJournal>{};
    final rawShootingDayJournals = json['shootingDayJournals'];

    if (rawShootingDayJournals is Map) {
      for (final entry in rawShootingDayJournals.entries) {
        final dayId = entry.key.toString();
        final rawJournal = entry.value;

        if (dayId.isEmpty || rawJournal is! Map) {
          continue;
        }

        final journal = ShootingDayJournal.fromJson(
          rawJournal.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );

        if (!journal.isDefault) {
          shootingDayJournals[dayId] = journal;
        }
      }
    }

    final scenePostProduction = <String, ScenePostProductionData>{};
    final rawScenePostProduction = json['scenePostProduction'];

    if (rawScenePostProduction is Map) {
      for (final entry in rawScenePostProduction.entries) {
        final sceneId = entry.key.toString();
        final rawData = entry.value;

        if (sceneId.isEmpty || rawData is! Map) {
          continue;
        }

        final data = ScenePostProductionData.fromJson(
          rawData.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );

        if (!data.isDefault) {
          scenePostProduction[sceneId] = data;
        }
      }
    }

    final postProductionSequences = <PostProductionSequence>[];
    final rawPostProductionSequences = json['postProductionSequences'];

    if (rawPostProductionSequences is List) {
      for (final rawSequence in rawPostProductionSequences) {
        if (rawSequence is! Map) {
          continue;
        }

        postProductionSequences.add(
          PostProductionSequence.fromJson(
            rawSequence.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      }
    }

    final editVersions = <EditVersion>[];
    final rawEditVersions = json['editVersions'];

    if (rawEditVersions is List) {
      for (final rawVersion in rawEditVersions) {
        if (rawVersion is! Map) {
          continue;
        }

        editVersions.add(
          EditVersion.fromJson(
            rawVersion.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      }
    }

    final postProductionTasks = <PostProductionTask>[];
    final rawPostProductionTasks = json['postProductionTasks'];

    if (rawPostProductionTasks is List) {
      for (final rawTask in rawPostProductionTasks) {
        if (rawTask is! Map) {
          continue;
        }

        postProductionTasks.add(
          PostProductionTask.fromJson(
            rawTask.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      }
    }

    final missingMaterials = <MissingMaterialItem>[];
    final rawMissingMaterials = json['missingMaterials'];

    if (rawMissingMaterials is List) {
      for (final rawItem in rawMissingMaterials) {
        if (rawItem is! Map) {
          continue;
        }

        missingMaterials.add(
          MissingMaterialItem.fromJson(
            rawItem.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      }
    }

    final projectMembers = <ProjectMember>[];
    final rawProjectMembers = json['projectMembers'];

    if (rawProjectMembers is List) {
      for (final rawMember in rawProjectMembers) {
        if (rawMember is! Map) {
          continue;
        }

        projectMembers.add(
          ProjectMember.fromJson(
            rawMember.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      }
    }

    final collaborationComments = <CollaborationComment>[];
    final rawCollaborationComments = json['collaborationComments'];

    if (rawCollaborationComments is List) {
      for (final rawComment in rawCollaborationComments) {
        if (rawComment is! Map) {
          continue;
        }

        collaborationComments.add(
          CollaborationComment.fromJson(
            rawComment.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      }
    }

    final projectChangeLog = <ProjectChangeEntry>[];
    final rawProjectChangeLog = json['projectChangeLog'];

    if (rawProjectChangeLog is List) {
      for (final rawEntry in rawProjectChangeLog) {
        if (rawEntry is! Map) {
          continue;
        }

        projectChangeLog.add(
          ProjectChangeEntry.fromJson(
            rawEntry.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      }
    }

    final projectCheckpoints = <ProjectCheckpoint>[];
    final rawProjectCheckpoints = json['projectCheckpoints'];

    if (rawProjectCheckpoints is List) {
      for (final rawCheckpoint in rawProjectCheckpoints) {
        if (rawCheckpoint is! Map) {
          continue;
        }

        projectCheckpoints.add(
          ProjectCheckpoint.fromJson(
            rawCheckpoint.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      }
    }

    final creativeMaterials = <CreativeMaterial>[];
    final rawCreativeMaterials = json['creativeMaterials'];

    if (rawCreativeMaterials is List) {
      for (final rawMaterial in rawCreativeMaterials) {
        if (rawMaterial is! Map) {
          continue;
        }

        creativeMaterials.add(
          CreativeMaterial.fromJson(
            rawMaterial.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      }
    }

    ProjectVersioningSettings versioningSettings =
        const ProjectVersioningSettings();
    final rawVersioningSettings = json['versioningSettings'];

    if (rawVersioningSettings is Map) {
      versioningSettings = ProjectVersioningSettings.fromJson(
        rawVersioningSettings.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
    }

    final rawBudgetCurrency = json['budgetCurrency']?.toString().trim();
    final budgetCurrency =
        rawBudgetCurrency == null || rawBudgetCurrency.isEmpty
            ? 'TJS'
            : rawBudgetCurrency.toUpperCase();

    ScreenplayGoals goals = const ScreenplayGoals();
    final rawGoals = json['goals'];

    if (rawGoals is Map) {
      goals = ScreenplayGoals.fromJson(
        rawGoals.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
    }

    final validSceneIds = blocks
        .where((block) => block.type == BlockType.sceneHeading)
        .map((block) => block.id)
        .toSet();
    final validBlockIds = blocks.map((block) => block.id).toSet();
    final normalizedCreativeMaterials = creativeMaterials.map((material) {
      return material.copyWith(
        linkedSceneIds: material.linkedSceneIds
            .where(validSceneIds.contains)
            .toSet()
            .toList(growable: false),
        usedBlockIds: material.usedBlockIds
            .where(validBlockIds.contains)
            .toSet()
            .toList(growable: false),
      );
    }).toList(growable: false);

    notes.removeWhere((sceneId, _) => !validSceneIds.contains(sceneId));
    development.removeWhere(
      (sceneId, _) => !validSceneIds.contains(sceneId),
    );
    production.removeWhere(
      (sceneId, _) => !validSceneIds.contains(sceneId),
    );
    storyboardShots.removeWhere(
      (sceneId, _) => !validSceneIds.contains(sceneId),
    );

    final validShotIds = storyboardShots.values
        .expand((shots) => shots)
        .map((shot) => shot.id)
        .toSet();
    shotTakes.removeWhere((shotId, _) => !validShotIds.contains(shotId));

    final normalizedDays = shootingDays.map((day) {
      final sceneIds =
          day.sceneIds.where(validSceneIds.contains).toList(growable: false);
      return day.copyWith(sceneIds: sceneIds);
    }).toList(growable: false);

    final validShootingDayIds = normalizedDays.map((day) => day.id).toSet();
    shootingDayJournals.removeWhere(
      (dayId, _) => !validShootingDayIds.contains(dayId),
    );

    final normalizedShotTakes = <String, List<ShotTake>>{
      for (final entry in shotTakes.entries)
        entry.key: entry.value
            .map(
              (take) => take.shootingDayId != null &&
                      !validShootingDayIds.contains(take.shootingDayId)
                  ? take.copyWith(clearShootingDayId: true)
                  : take,
            )
            .toList(growable: true),
    };

    scenePostProduction.removeWhere(
      (sceneId, _) => !validSceneIds.contains(sceneId),
    );
    final normalizedScenePostProduction = <String, ScenePostProductionData>{};

    for (final entry in scenePostProduction.entries) {
      final sceneShotIds =
          storyboardShots[entry.key]?.map((shot) => shot.id).toSet() ??
              const <String>{};
      final sceneTakeIds = sceneShotIds
          .expand((shotId) => normalizedShotTakes[shotId] ?? const <ShotTake>[])
          .map((take) => take.id)
          .toSet();
      final data = entry.value.copyWith(
        selectedTakeIds: entry.value.selectedTakeIds
            .where(sceneTakeIds.contains)
            .toList(growable: false),
      );

      if (!data.isDefault) {
        normalizedScenePostProduction[entry.key] = data;
      }
    }

    final normalizedSequences = postProductionSequences.map((sequence) {
      return sequence.copyWith(
        sceneIds: sequence.sceneIds
            .where(validSceneIds.contains)
            .toSet()
            .toList(growable: false),
      );
    }).toList(growable: false);
    final validSequenceIds = normalizedSequences.map((item) => item.id).toSet();
    final normalizedVersions = editVersions.map((version) {
      return version.sequenceId != null &&
              !validSequenceIds.contains(version.sequenceId)
          ? version.copyWith(clearSequenceId: true)
          : version;
    }).toList(growable: false);
    final validVersionIds = normalizedVersions.map((item) => item.id).toSet();
    final normalizedPostTasks = postProductionTasks.map((task) {
      return task.copyWith(
        clearSceneId:
            task.sceneId != null && !validSceneIds.contains(task.sceneId),
        clearVersionId:
            task.versionId != null && !validVersionIds.contains(task.versionId),
      );
    }).toList(growable: false);
    final normalizedMissingMaterials = missingMaterials.map((item) {
      return item.copyWith(
        clearSceneId:
            item.sceneId != null && !validSceneIds.contains(item.sceneId),
        clearShotId: item.shotId != null && !validShotIds.contains(item.shotId),
      );
    }).toList(growable: false);

    final validMemberIds = projectMembers.map((member) => member.id).toSet();
    final validTakeIds = normalizedShotTakes.values
        .expand((takes) => takes)
        .map((take) => take.id)
        .toSet();
    final validTaskIds = normalizedPostTasks.map((task) => task.id).toSet();

    final normalizedComments = collaborationComments.map((comment) {
      final hasValidTarget = switch (comment.targetType) {
        CollaborationTargetType.project => true,
        CollaborationTargetType.scene =>
          comment.targetId != null && validSceneIds.contains(comment.targetId),
        CollaborationTargetType.shot =>
          comment.targetId != null && validShotIds.contains(comment.targetId),
        CollaborationTargetType.take =>
          comment.targetId != null && validTakeIds.contains(comment.targetId),
        CollaborationTargetType.task =>
          comment.targetId != null && validTaskIds.contains(comment.targetId),
      };

      return comment.copyWith(
        clearTargetId: !hasValidTarget,
        targetType: hasValidTarget
            ? comment.targetType
            : CollaborationTargetType.project,
        clearAuthorId: comment.authorId != null &&
            !validMemberIds.contains(comment.authorId),
        clearAssigneeId: comment.assigneeId != null &&
            !validMemberIds.contains(comment.assigneeId),
      );
    }).toList(growable: false);

    final normalizedBudgetItems = budgetItems.map((item) {
      return item.copyWith(
        clearSceneId:
            item.sceneId != null && !validSceneIds.contains(item.sceneId),
        clearShootingDayId: item.shootingDayId != null &&
            !validShootingDayIds.contains(item.shootingDayId),
      );
    }).toList(growable: false);

    return FilmDocument(
      blocks: blocks,
      sceneNotes: notes,
      sceneDevelopment: development,
      sceneProduction: production,
      shootingDays: normalizedDays,
      productionPeople: productionPeople,
      budgetItems: normalizedBudgetItems,
      storyboardShots: storyboardShots,
      shotTakes: normalizedShotTakes,
      shootingDayJournals: shootingDayJournals,
      scenePostProduction: normalizedScenePostProduction,
      postProductionSequences: normalizedSequences,
      editVersions: normalizedVersions,
      postProductionTasks: normalizedPostTasks,
      missingMaterials: normalizedMissingMaterials,
      projectMembers: projectMembers,
      collaborationComments: normalizedComments,
      projectChangeLog: projectChangeLog,
      projectCheckpoints: projectCheckpoints,
      creativeMaterials: normalizedCreativeMaterials,
      versioningSettings: versioningSettings,
      budgetCurrency: budgetCurrency,
      goals: goals,
    );
  }
}
