Feature: database with append 
  The database should allow storage of new objects after the database
  was created and closed.

  Background:
    Given the library works in development mode

  Scenario: simple append
    Given the class space is cleared
    And the model is connected with the default database
    And a class User has a name field of type string
    When database is created
    And I create a User
    And his name is 'Fred'
    And I store him in the database 1000 times
    And I reopen database
    And I store him in the database 1000 times
    And I reopen database
    Then there should be 2000 User(s)

  Scenario: append with indexing
    Given the class space is cleared
    And the model is connected with the default database
    And a class User has a name field of type string with flat index
    And a class User has a surname field of type string with flat index
    And a class User has a login field of type string
    And a class User has an age field of type integer
    When database is created
    And I create and store the following User(s):
      | name | surname | login | age  |
      | John | Smith   | john  | 12   |
      | Lara | Croft   | lara  | 23   |
      | Adam | Parker  | adam  | 17   |
    And I reopen database
    And I create and store the following User(s):
      | name | surname | login | age  |
      | Mike | Spike   | mike  | 60   |
      | Lara | Cook    | larac | 61   |
      | Adam | Smith   | adams | 17   |
    And I reopen database
    Then there should be 6 User(s)
    And there should be 1 User with 'Mike' name
    And there should be 1 User with 'John' name
    And there should be 2 User(s) with 'Lara' name
    And there should be 2 User(s) with 'Adam' name

    And there should be 2 User(s) with 'Smith' surname
    And there should be 1 User with 'Croft' surname
    And there should be 1 User with 'Parker' surname
    And there should be 1 User with 'Spike' surname
    And there should be 1 User with 'Cook' surname

  Scenario: append with has one
    Given the class space is cleared
    And the model is connected with the default database
    And a class Automobile has a name field of type string
    And a class Caveman has a name field of type string
    And a class Caveman has one automobile
    When the database is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I store it in the database
    And I create a Caveman
    And his name is 'Fred'
    And his automobile is the first Automobile created
    And I store him in the database
    And I reopen database
    And I create an Automobile
    And its name is 'Modern car'
    And I store it in the database
    And I create a Caveman
    And her name is 'Willma'
    And her automobile is the second Automobile created
    And I store her in the database
    And I reopen database
    Then there should be 2 Caveman(s)
    And there should be 2 Automobile(s)
    And the name of the first Caveman should be 'Fred'
    And the name of the first Automobile should be 'Prehistoric car'
    And the name of the second Caveman should be 'Willma'
    And the name of the second Automobile should be 'Modern car'
    And the automobile of the first Caveman should be equal to the first Automobile
    And the automobile of the second Caveman should be equal to the second Automobile

  Scenario: append with has many
    Given the class space is cleared
    And the model is connected with the default database
    And a class Automobile has a name field of type string
    And a class Caveman has a name field of type string
    And a class Caveman has many automobiles
    When the database is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I store it in the database
    And I create another Automobile
    And its name is 'Modern car'
    And I store it in the database
    And I create a Caveman
    And his name is 'Fred'
    And his automobiles contain the first Automobile created
    And his automobiles contain the second Automobile created
    And I store him in the database
    And I reopen database
    And I create a Caveman
    And her name is 'Willma'
    And her automobiles contain the first Automobile created
    And her automobiles contain the second Automobile created
    And I store her in the database
    And I reopen database for reading
    Then there should be 2 Caveman(s)
    And there should be 2 Automobile(s)
    And the name of the first Caveman should be 'Fred'
    And the name of the first Automobile should be 'Prehistoric car'
    And the name of the second Automobile should be 'Modern car'
    And the first Caveman should have 2 automobiles
    And the first of automobiles of the first Caveman should be equal to the first Automobile
    And the second of automobiles of the first Caveman should be equal to the second Automobile
    And the name of the second Caveman should be 'Willma'
    And the second Caveman should have 2 automobiles
    And the first of automobiles of the second Caveman should be equal to the first Automobile
    And the second of automobiles of the second Caveman should be equal to the second Automobile

  Scenario: append with a new class
    Given the class space is cleared
    And the model is connected with the default database
    And a class Automobile has a name field of type string
    When database is created
    And I create an Automobile
    And his name is 'Prehistoric car'
    And I store him in the database
    And I reopen database
    Then there should be 1 Automobile

    Given the class space is cleared
    And the model is connected with the default database
    And a class Automobile has a name field of type string
    And a class Caveman has a name field of type string 
    When I open database
    And I create a Caveman
    And his name is 'Fred'
    And I store him in the database
    Then there should be 1 Automobile
    And the name of the first Automobile should be 'Prehistoric car'
    And there should be 1 Caveman
    And the name of the first Caveman should be 'Fred'

  Scenario: append of has many associations with indexing
      It should be possible to append elements to has many association.
    Given the class space is cleared
    And the model is connected with the default database
    And a class Automobile has a name field of type string
    And a class Caveman has a name field of type string
    And a class Caveman has many automobiles with flat index
    When the database is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I store it in the database
    And I create a Caveman
    And his name is 'Fred'
    And his automobiles contain the first Automobile created
    And I store him in the database
    And I reopen database
    And I create an Automobile
    And its name is 'Modern car'
    And I store it in the database
    And I fetch the first Caveman
    And his automobiles contain the second Automobile created
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And there should be 2 Automobile(s)
    And the name of the first Caveman should be 'Fred'
    And the name of the first Automobile should be 'Prehistoric car'
    And the name of the second Automobile should be 'Modern car'
    And the first Caveman should have 2 automobiles
    And the first of automobiles of the first Caveman should be equal to the first Automobile
    And the second of automobiles of the first Caveman should be equal to the second Automobile
    And there should be 1 Caveman with the first Automobile as automobiles
    And there should be 1 Caveman with the second Automobile as automobiles

  # Enable for #94
  @ignore
  Scenario: append of has many associations with indexing with and unstored object
      Same as above, but with an object which is appended to the collection
      while it is not yet stored in the DB.
    Given the class space is cleared
    And the model is connected with the default database
    And a class Automobile has a name field of type string
    And a class Caveman has a name field of type string
    And a class Caveman has many automobiles with flat index
    When the database is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I store it in the database
    And I create a Caveman
    And his name is 'Fred'
    And his automobiles contain the first Automobile created
    And I store him in the database
    And I create an Automobile
    And its name is 'Modern car'
    And I fetch the first Caveman
    And his automobiles contain the second Automobile created
    And I store him in the database
    And I fetch the second Automobile created
    And I store it in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And there should be 2 Automobile(s)
    And the name of the first Caveman should be 'Fred'
    And the name of the first Automobile should be 'Prehistoric car'
    And the name of the second Automobile should be 'Modern car'
    And the first Caveman should have 2 automobiles
    And the first of automobiles of the first Caveman should be equal to the first Automobile
    And the second of automobiles of the first Caveman should be equal to the second Automobile
    And there should be 1 Caveman with the first Automobile as automobiles
    And there should be 1 Caveman with the second Automobile as automobiles
