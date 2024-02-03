# **Stanford Participatory Budgeting Platform** #
The Stanford Participatory Budgeting Platform has been developed by the [Stanford Crowdsourced Democracy Team](https://voxpopuli.stanford.edu/). The platform is being used by many cities across the United States for hosting participatory budgeting elections. You can check out the live platform hosted at [https://pbstanford.org/](https://pbstanford.org/).

The platform is built with Ruby on Rails, Bootstrap, jQuery, and React.

## **Requirements** ##
* **Ruby**: >= 3.2.1
* **Database**: MySQL, PostgreSQL or SQLite (Preferrred: MySQL) 

## **Getting Started** ##
1. Download the project to your local machine.
2. Add your local database configuration to a ``config/database.yml`` file using the ``config/database.yml.example`` file for reference.
3. Run the ``bin/setup`` executable which installs all the dependencies for the project as well as sets up the database.
4. Add the following credentials to a ``config/secrets.yml`` file using the ``config/secrets.yml.example`` file for reference:
   * Generate a private key for signing cookies and add it to ``secret_key_base``. **Do not** use the key in the example file.
   * Create an email account for sending emails and add it to `email`.
   * (Optional) Create a Twilio account for sending SMS and add it to ``twilio``.
   * (Optional) Sign up for a Google Maps API key for showing maps on the website and add it to `google_maps_api_key`.
5. Start the local Rails server on your machine by using the ``rails server`` command and then run the application by opening ``http://localhost:3000`` in your browser.
6. You can access the admin interface by going to ``http://localhost:3000/admin`` and logging in with the email "s@s" and password "superadmin123". **Change the password** to something more secure immediately after the first login.

## **Contributing** ##
We currently **do not** accept pull requests. If you have any questions or suggestions, please contact us at contact@pbstanford.org

## **License** ##
Participatory Budgeting Platform is released under the GNU General Public License, version 3.
